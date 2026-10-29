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

options() { printf '{"address": "%s", "invite_only": false, "first_user_admin": true}' "$1" > "$DATA/options.json"; }

start() {
  options "$1"
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  docker run -d --name "$NAME" -v "$DATA:/data" -p 18099:8099 "$IMG" >/dev/null
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

echo "OK"
