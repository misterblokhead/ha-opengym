#!/bin/bash
# Builds the app image, starts it the way the Supervisor does, and checks the pieces that matter.
set -euo pipefail

IMG=opengym-test
NAME=opengym-test-run
URL=http://127.0.0.1:18099
DATA=$(mktemp -d)
# A fake Supervisor token, to check that it never reaches openGym or nginx.
TOKEN=fake-supervisor-token-for-the-test

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  # /data/opengym belongs to the container's coach user
  docker run --rm --entrypoint sh -v "$DATA:/data" "$IMG" -c 'rm -rf /data/*' >/dev/null 2>&1 || true
  rm -rf "$DATA"
}
trap cleanup EXIT

fail() { echo "FAIL: $*"; docker logs "$NAME" 2>&1 | tail -n 40 || true; exit 1; }

options() { printf '{"address": "%s", "invite_only": false, "first_user_admin": true}' "$1" > "$DATA/options.json"; }

start() {
  options "$1"
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run -d --name "$NAME" -e SUPERVISOR_TOKEN="$TOKEN" -e HASSIO_TOKEN="$TOKEN" -v "$DATA:/data" -p 18099:8099 "$IMG" >/dev/null
}

healthy() {
  for _ in $(seq 60); do
    curl -sf "$URL/api/health" >/dev/null && return 0
    sleep 1
  done
  fail "no health answer within 60 s"
}

docker build opengym -t "$IMG"

# An address with a path never starts the app.
options https://ha.example.test/lovelace
OUT=$(docker run --rm -v "$DATA:/data" "$IMG" 2>&1) && fail "started with a path in the address"
grep -q 'is not an https address without a path' <<<"$OUT" || fail "no message for an address with a path: $OUT"

# Nor does an IP address: passkeys never work on one.
for ip in https://192.0.2.1 'https://[2001:db8::1]'; do
  options "$ip"
  OUT=$(docker run --rm -v "$DATA:/data" "$IMG" 2>&1) && fail "started with the IP address $ip"
  grep -q 'or it is an IP address' <<<"$OUT" || fail "no message for the IP address $ip: $OUT"
done

start https://ha.example.test/
healthy
HEALTH=$(curl -sf "$URL/api/health") || fail "no health answer"

grep -q '"ok":true' <<<"$HEALTH" || fail "health is not ok: $HEALTH"
HEADERS=$(curl -sI "$URL/")
grep -qi '^X-Frame-Options: SAMEORIGIN' <<<"$HEADERS" || fail "X-Frame-Options is not SAMEORIGIN"
grep -i '^Content-Security-Policy:' <<<"$HEADERS" | grep -q "frame-ancestors 'self'" || fail "CSP lacks frame-ancestors 'self'"
LOGS=$(docker logs "$NAME" 2>&1)
grep -q 'rpID=ha.example.test' <<<"$LOGS" || fail "log lacks rpID=ha.example.test"
[ ! -e "$DATA/address" ] || fail "/data/address was written before openGym held data"

# openGym and nginx run unprivileged, and no long-running process holds the token (docker exec itself gets it, so each
# check reads the other processes' environment, never its own).
PS=$(docker exec "$NAME" ps -o user,args)
grep -Eq '^coach +node server.js' <<<"$PS" || fail "openGym does not run as coach: $PS"
grep -Eq '^nginx +nginx: master' <<<"$PS" || fail "nginx does not run as nginx: $PS"
grep -Eq '^root +(node|nginx)' <<<"$PS" && fail "openGym or nginx runs as root: $PS"
for p in 1 $(docker exec "$NAME" pidof node nginx); do
  docker exec "$NAME" grep -aq "$TOKEN" "/proc/$p/environ" && fail "process $p holds the Supervisor token"
done
docker exec -u coach "$NAME" cat /proc/1/environ >/dev/null 2>&1 && fail "coach can read PID 1's environment"
[ -z "$(docker exec "$NAME" find /data/opengym ! -user coach)" ] || fail "/data/opengym has files coach does not own"

# Second run: openGym holds data now, so the address is stored.
start https://ha.example.test
healthy
[ "$(cat "$DATA/address")" = "https://ha.example.test" ] || fail "/data/address is not https://ha.example.test"

# Third run, other address: the change is logged and the stored address kept.
start https://other.example.test
for _ in $(seq 30); do
  LOGS=$(docker logs "$NAME" 2>&1)
  grep -q 'The address changed' <<<"$LOGS" && break
  sleep 1
done
grep -q 'The address changed' <<<"$LOGS" || fail "no 'The address changed' warning"
[ "$(cat "$DATA/address")" = "https://ha.example.test" ] || fail "/data/address was overwritten"

# Data from a version that ran as root (before 1.1.0) is handed to coach at start.
docker rm -f "$NAME" >/dev/null
docker run --rm --entrypoint sh -v "$DATA:/data" "$IMG" -c 'echo {} > /data/opengym/from-root.json && chmod 600 /data/opengym/from-root.json'
start https://ha.example.test
healthy
[ -z "$(docker exec "$NAME" find /data/opengym ! -user coach)" ] || fail "root-owned data was not handed to coach"

echo "OK"
