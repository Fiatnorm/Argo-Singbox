#!/usr/bin/env bash
set -Eeuo pipefail
export UI_LANGUAGE=zh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../argo-singbox.sh
source "${ROOT_DIR}/argo-singbox.sh"

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

WORK_DIR="${TEST_DIR}/work"
CONFIG_DIR="${WORK_DIR}/config"
DATA_DIR="${WORK_DIR}/data"
SUBSCRIPTION_DIR="${WORK_DIR}/subscriptions"
SING_BOX_CONFIG="${CONFIG_DIR}/sing-box.json"
TRAFFIC_DB="${DATA_DIR}/traffic.db"
TRAFFIC_ERROR_FILE="${DATA_DIR}/traffic.last_error"
CORE_SERVICE="argo-singbox-core"
STATS_API_PORT=18085
TEST_PID="$$"
TEST_START=100
TEST_ACTIVE=1
TEST_RESPONSE="${TEST_DIR}/connections.json"

ensure_project_layout() {
  mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$SUBSCRIPTION_DIR"
}
load_env() { :; }
flock() { return 0; }
systemctl() {
  case "${1:-}" in
    show) printf '%s\n' "$TEST_PID" ;;
    is-active) [[ "$TEST_ACTIVE" == "1" ]] ;;
    *) return 0 ;;
  esac
}
readlink() {
  if [[ "${*: -1}" == "/proc/${TEST_PID}/exe" ]]; then
    printf '%s\n' "${TEST_DIR}/sing-box"
  else
    command readlink "$@"
  fi
}
awk() {
  if [[ "${*: -1}" == "/proc/${TEST_PID}/stat" ]]; then
    printf '%s\n' "$TEST_START"
  else
    command awk "$@"
  fi
}
curl() { command cat "$TEST_RESPONSE"; }
if ! command -v jq >/dev/null 2>&1; then
  jq() {
    local args="$*" file
    if [[ "$args" == *"external_controller"* ]]; then
      file="${*: -1}"
      node -e 'const f=require("fs");const j=JSON.parse(f.readFileSync(process.argv[1],"utf8"));process.stdout.write(j.experimental?.clash_api?.external_controller||"")' "$file"
    elif [[ "${1:-}" == "-e" ]]; then
      node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);process.exit(Number.isFinite(j.uploadTotal)&&j.uploadTotal>=0&&Number.isFinite(j.downloadTotal)&&j.downloadTotal>=0?0:1)})'
    else
      node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const j=JSON.parse(s);process.stdout.write(`${j.uploadTotal}\t${j.downloadTotal}\n`)})'
    fi
  }
fi

assert_sql() {
  local sql="$1" expected="$2" actual
  actual="$(sqlite3 -separator '|' "$TRAFFIC_DB" "$sql")"
  [[ "$actual" == "$expected" ]] || {
    printf 'assertion failed\nSQL: %s\nexpected: %s\nactual: %s\n' "$sql" "$expected" "$actual" >&2
    exit 1
  }
}

mkdir -p "$CONFIG_DIR" "$DATA_DIR"
printf '%s\n' '{"experimental":{"clash_api":{"external_controller":"127.0.0.1:18085"}}}' >"$SING_BOX_CONFIG"
sqlite3 "$TRAFFIC_DB" "CREATE TABLE obsolete_details (name TEXT); INSERT INTO obsolete_details VALUES ('old');"
ensure_traffic_database
ensure_traffic_database
assert_sql "SELECT group_concat(name, ',') FROM (SELECT name FROM sqlite_master WHERE type='table' ORDER BY name);" "global_baseline,global_totals,meta"

printf '%s\n' '{"uploadTotal":1000,"downloadTotal":2000,"connections":[{"upload":900000,"download":800000,"metadata":{"inbound":"node-a"}}]}' >"$TEST_RESPONSE"
traffic_collect
assert_sql "SELECT uplink,downlink FROM global_totals WHERE id=1;" "1000|2000"

printf '%s\n' '{"uploadTotal":1300,"downloadTotal":2600}' >"$TEST_RESPONSE"
traffic_collect
assert_sql "SELECT uplink,downlink FROM global_totals WHERE id=1;" "1300|2600"

TEST_START=200
printf '%s\n' '{"uploadTotal":50,"downloadTotal":80}' >"$TEST_RESPONSE"
traffic_collect
assert_sql "SELECT uplink,downlink FROM global_totals WHERE id=1;" "1350|2680"

printf '%s\n' '{"uploadTotal":10,"downloadTotal":20}' >"$TEST_RESPONSE"
traffic_collect
assert_sql "SELECT uplink,downlink FROM global_totals WHERE id=1;" "1360|2700"

traffic_reset
assert_sql "SELECT count(*) FROM global_totals;" "0"
assert_sql "SELECT upload_total,download_total FROM global_baseline WHERE id=1;" "10|20"
printf '%s\n' '{"uploadTotal":15,"downloadTotal":30}' >"$TEST_RESPONSE"
traffic_collect
assert_sql "SELECT uplink,downlink FROM global_totals WHERE id=1;" "5|10"

TEST_ACTIVE=0
traffic_reset
assert_sql "SELECT count(*) FROM global_totals;" "0"
assert_sql "SELECT count(*) FROM global_baseline;" "0"
TEST_ACTIVE=1
printf '%s\n' '{"uploadTotal":7,"downloadTotal":11}' >"$TEST_RESPONSE"
traffic_collect
assert_sql "SELECT uplink,downlink FROM global_totals WHERE id=1;" "7|11"

[[ ! -e "$TRAFFIC_ERROR_FILE" ]]
[[ "$(format_traffic_bytes 0)" == "0 B" ]]
[[ "$(format_traffic_bytes 1099511627776)" == "1.0 TiB" ]]
[[ "$(format_traffic_bytes 1125899906842624)" == "1.0 PiB" ]]
[[ "$(format_traffic_bytes 9223372036854775807)" == "8.0 EiB" ]]
table_output="$({ traffic_table_header; traffic_table_row "全局流量" 1125899906842624 2251799813685248; })"
while IFS= read -r line; do
  (( $(display_width "$line") <= 64 )) || { printf 'traffic row exceeds 64 columns: %s\n' "$line" >&2; exit 1; }
done <<<"$table_output"
printf '%s\n' 'TRAFFIC_GLOBAL_SMOKE_OK'
