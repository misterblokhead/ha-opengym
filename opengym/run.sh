#!/bin/sh
set -e

opt() { node -e "try{const v=require('/data/options.json')['$1'];process.stdout.write(v==null?'':String(v))}catch{}"; }
flag() { [ "$(opt "$1")" = true ] && echo 1 || echo 0; }

ADDRESS=$(opt address)
[ -n "$ADDRESS" ] || ADDRESS=$(node /opt/opengym/address.mjs)
[ -n "$ADDRESS" ] || { echo 'No address found: set "address" to the https address people open Home Assistant at'; exit 1; }
# The origin and its host, only for an https host name without a path, query or fragment (a path in ORIGIN breaks every
# passkey, and passkeys never work on an IP address).
set -- $(node -e 'try{const u=new URL(process.argv[1]);if(u.protocol==="https:"&&u.hostname&&!require("net").isIP(u.hostname.replace(/^\[|\]$/g,""))&&u.pathname==="/"&&!u.search&&!u.hash&&!u.username&&!u.password)console.log(u.origin,u.hostname)}catch{}' "$ADDRESS")
[ $# -eq 2 ] || { echo "\"$ADDRESS\" is not an https address without a path, or it is an IP address: set \"address\" to the address people open Home Assistant at, for example https://home.example.com"; exit 1; }
ORIGIN=$1 RP_ID=$2
# The token reaches Core's API: only address.mjs needs it, not openGym or nginx.
unset SUPERVISOR_TOKEN HASSIO_TOKEN

# Passkeys are bound to the address they were made at: remember it once openGym holds data, warn when it changes.
if [ -f /data/address ]; then
  OLD=$(cat /data/address)
  [ "$OLD" = "$ORIGIN" ] || echo "The address changed from $OLD to $ORIGIN: passkeys made for $OLD stop working"
elif [ -n "$(ls -A /data/opengym 2>/dev/null)" ]; then
  printf '%s' "$ORIGIN" > /data/address
fi

INVITE_ONLY=$(flag invite_only)
FIRST_USER_ADMIN=$(flag first_user_admin)
export ORIGIN RP_ID INVITE_ONLY FIRST_USER_ADMIN RP_NAME=openGym DATA_DIR=/data/opengym PORT=3000 TRUST_PROXY=1 ALLOW_GUEST=0 PASSWORD_LOGIN=0 NODE_ENV=production
mkdir -p "$DATA_DIR"
cd /app
node server.js &
API=$!

# 8099 is the ingress port ChallengeHouse (custom_components/fitbridge/opengym_app.py) connects to.
export NGINX_PORT=8099 BACKEND=127.0.0.1 RESOLVER=127.0.0.1 BASE_PATH= CF_CONNECTING_IP= MEDIA_UPLOAD_MAX=48m
CONTENT_SECURITY_POLICY=$(cat /etc/opengym/csp)
export CONTENT_SECURITY_POLICY
envsubst '$NGINX_PORT $BACKEND $PORT $RESOLVER $BASE_PATH $CF_CONNECTING_IP $MEDIA_UPLOAD_MAX $CONTENT_SECURITY_POLICY' < /etc/opengym/nginx.conf.template > /etc/nginx/http.d/default.conf
nginx -g 'daemon off;' &
NGINX=$!

# Stop node first, then nginx. Either process dying ends the app; the Supervisor restarts it only when Watchdog is on.
stop() {
  kill "$API" 2>/dev/null || true; wait "$API" 2>/dev/null || true
  kill "$NGINX" 2>/dev/null || true; wait "$NGINX" 2>/dev/null || true
}
trap 'stop; exit 0' TERM INT
while kill -0 "$API" 2>/dev/null && kill -0 "$NGINX" 2>/dev/null; do
  sleep 5 & wait $!
done
echo "openGym API or nginx stopped, exiting"
stop
exit 1
