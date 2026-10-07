#!/usr/bin/env bash
set -Eeuo pipefail
export UI_LANGUAGE=zh
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
for mode in plain dumb no-color; do
  (
    case "$mode" in
      plain) unset NO_COLOR; export TERM=xterm ;;
      dumb) unset NO_COLOR; export TERM=dumb ;;
      no-color) export NO_COLOR=1 TERM=xterm ;;
    esac
    source "${ROOT_DIR}/argo-singbox.sh"
    system_summary() { printf 'Debian 13 · amd64 · Kernel 6.12'; }
    SCRIPT_RUNS_REQUESTED=1
    SCRIPT_RUNS_TOTAL=1234
    control_panel
    brand 'Argo-Singbox · 控制中心' main
    SCRIPT_RUNS_SHOWN=0
    SCRIPT_RUNS_TOTAL=99999999999999999999999999999999999999999999999999999999999
    show_script_runs
    SCRIPT_RUNS_SHOWN=0
    SCRIPT_RUNS_TOTAL=""
    show_script_runs
  ) >"${TEST_DIR}/${mode}"
  ! grep -q $'\033' "${TEST_DIR}/${mode}"
  grep -q 'Executed 1234 times' "${TEST_DIR}/${mode}"
  grep -q 'Unavailable' "${TEST_DIR}/${mode}"
  source "${ROOT_DIR}/argo-singbox.sh"
  while IFS= read -r line; do
    [[ "$line" == Argo-Singbox*WSS\ Proxy || "$line" == 脚本统计* ]] || [[ "$(display_width "$line")" -le 64 ]] || {
      printf 'UI exceeds 64 columns: %s\n' "$line" >&2
      exit 1
    }
  done <"${TEST_DIR}/${mode}"
done
printf 'UI smoke: ok\n'
