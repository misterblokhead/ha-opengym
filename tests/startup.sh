#!/bin/bash
# Builds the app image, starts it the way the Supervisor does, and checks the pieces that matter.
set -euo pipefail

IMG=opengym-test
NAME=opengym-test-run
URL=http://127.0.0.1:18099
DATA=$(mktemp -d)

cleanup() {
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  # /data/opengym is written by root inside the container
  docker run --rm --entrypoint sh -v "$DATA:/data" "$IMG" -c 'rm -rf /data/*' >/dev/null 2>&1 || true
  rm -rf "$DATA"
}
trap cleanup EXIT

fail() { echo "FAIL: $*"; docker logs "$NAME" 2>&1 | tail -n 40 || true; exit 1; }

start() {
  printf '{"address": "%s", "invite_only": false, "first_user_admin": true}' "$1" > "$DATA/options.json"
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run -d --name "$NAME" -v "$DATA:/data" -p 18099:8099 "$IMG" >/dev/null
}

docker build opengym -t "$IMG"

start https://ha.example.test
for _ in $(seq 60); do
  curl -sf "$URL/api/health" >/dev/null && break
  sleep 1
done
HEALTH=$(curl -sf "$URL/api/health") || fail "no health answer within 60 s"

grep -q '"ok":true' <<<"$HEALTH" || fail "health is not ok: $HEALTH"
HEADERS=$(curl -sI "$URL/")
grep -qi '^X-Frame-Options: SAMEORIGIN' <<<"$HEADERS" || fail "X-Frame-Options is not SAMEORIGIN"
grep -i '^Content-Security-Policy:' <<<"$HEADERS" | grep -q "frame-ancestors 'self'" || fail "CSP lacks frame-ancestors 'self'"
LOGS=$(docker logs "$NAME" 2>&1)
grep -q 'rpID=ha.example.test' <<<"$LOGS" || fail "log lacks rpID=ha.example.test"
[ "$(cat "$DATA/address")" = "https://ha.example.test" ] || fail "/data/address is not https://ha.example.test"

# Second run, other address: the change is logged.
start https://other.example.test
for _ in $(seq 30); do
  LOGS=$(docker logs "$NAME" 2>&1)
  grep -q 'The address changed' <<<"$LOGS" && break
  sleep 1
done
grep -q 'The address changed' <<<"$LOGS" || fail "no 'The address changed' warning"

echo "OK"
