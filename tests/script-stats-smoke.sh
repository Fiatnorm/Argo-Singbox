#!/usr/bin/env bash
set -Eeuo pipefail
export UI_LANGUAGE=zh
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
source "${ROOT_DIR}/argo-singbox.sh"
[[ "$SCRIPT_RUNS_REQUESTED" == 0 ]]
curl() {
  printf '%s\n' "$*" >>"${TEST_DIR}/requests"
  printf '%s' "$MOCK_RESPONSE"
  return "${MOCK_STATUS:-0}"
}
reset_stats() {
  SCRIPT_RUNS_REQUESTED=0
  SCRIPT_RUNS_SHOWN=0
  SCRIPT_RUNS_TOTAL=""
  MOCK_STATUS=0
  : >"${TEST_DIR}/requests"
}
reset_stats
MOCK_RESPONSE='{"value":1234}'
record_script_run
record_script_run
[[ "$SCRIPT_RUNS_TOTAL" == 1234 ]]
[[ "$(wc -l <"${TEST_DIR}/requests")" == 1 ]]
grep -q 'https://abacus.jasoncameron.dev/hit/ags/fiatnorm' "${TEST_DIR}/requests"
grep -q -- '--connect-timeout 2 --max-time 3' "${TEST_DIR}/requests"
! grep -Eq -- '--retry|Authorization|admin_key' "${TEST_DIR}/requests"
{ brand '测试页面'; brand '后续页面'; } >"${TEST_DIR}/output"
[[ "$(grep -c '脚本统计' "${TEST_DIR}/output")" == 1 ]]
grep -q 'Executed 1234 times' "${TEST_DIR}/output"
for MOCK_RESPONSE in '{"value":0}' $' \n{ "value" : 42 }\n' '{"value":99999999999999999999999999999999999999999999999999999999999}'; do
  reset_stats
  record_script_run
  [[ -n "$SCRIPT_RUNS_TOTAL" ]]
done
for MOCK_RESPONSE in '' '<html>error</html>' '{"value":-1}' '{"value":"12"}' '{"value":1.2}' '{"value":null}' '{"value":12,"error":"failed"}' '{"value":01}'; do
  reset_stats
  record_script_run
  [[ -z "$SCRIPT_RUNS_TOTAL" ]]
  show_script_runs >"${TEST_DIR}/output"
  grep -q 'Unavailable' "${TEST_DIR}/output"
done
for failure_status in 22 28 60; do
  reset_stats
  MOCK_STATUS="$failure_status"
  MOCK_RESPONSE='{"value":1234}'
  record_script_run
  [[ -z "$SCRIPT_RUNS_TOTAL" ]]
  [[ "$(wc -l <"${TEST_DIR}/requests")" == 1 ]]
done
reset_stats
MOCK_RESPONSE='{"value":42}'
record_script_run get
grep -q '/get/ags/fiatnorm' "${TEST_DIR}/requests"
[[ "$SCRIPT_RUNS_TOTAL" == 42 ]]
# 执行真实入口分派，替换业务动作，避免安装或流量采集的外部影响。
dispatcher="$(sed -n '/^if \[\[ "${BASH_SOURCE\[0\]}" == "\$0" \]\]; then/,$p' "${ROOT_DIR}/argo-singbox.sh")"
menu() { brand '测试菜单'; }
install_project() { brand '测试安装'; }
traffic_collect() { :; }
reset_stats
set -- --traffic-collect
eval "$dispatcher"
[[ ! -s "${TEST_DIR}/requests" && "$SCRIPT_RUNS_REQUESTED" == 0 ]]
reset_stats
set -- -i --github-refreshed
eval "$dispatcher" >"${TEST_DIR}/output"
[[ "$(wc -l <"${TEST_DIR}/requests")" == 1 ]]
grep -q '/get/' "${TEST_DIR}/requests"
reset_stats
set --
eval "$dispatcher" >"${TEST_DIR}/output"
grep -q '/hit/' "${TEST_DIR}/requests"
grep -q 'Executed 42 times' "${TEST_DIR}/output"
reset_stats
command() { [[ "${2:-}" != curl ]] && builtin command "$@"; }
record_script_run
[[ ! -s "${TEST_DIR}/requests" && -z "$SCRIPT_RUNS_TOTAL" ]]
printf 'script stats smoke: ok\n'
