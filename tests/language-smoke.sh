#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/argo-singbox.sh"
TEST_DIR="$(mktemp -d)"
unset UI_LANGUAGE
source "$SCRIPT"
trap 'rm -rf "$TEST_DIR"' EXIT
[[ "$UI_LANGUAGE" == zh ]]
CONFIG_DIR="$TEST_DIR/config"
require_root() { :; }
# Git Bash cannot apply Unix directory modes to these NTFS fixtures.
if [[ "${OSTYPE:-}" == msys* ]]; then
  install() { [[ "$1" == -d ]] && mkdir -p "${@: -1}" || command install "$@"; }
fi
configure_language >/dev/null <<'EOF'
2
EOF
[[ "$UI_LANGUAGE" == zh && "$(cat "$CONFIG_DIR/language")" == zh ]]
UI_LANGUAGE=en
load_language
[[ "$UI_LANGUAGE" == zh ]]
configure_language >/dev/null <<'EOF'
1
EOF
[[ "$UI_LANGUAGE" == en && "$(cat "$CONFIG_DIR/language")" == en ]]
printf 'invalid\n' >"$CONFIG_DIR/language"
UI_LANGUAGE=invalid
load_language
[[ "$UI_LANGUAGE" == zh ]]
UI_LANGUAGE=en
[[ "$(ui_text '节点概览')" == Nodes ]]
[[ "$(ui_text '执行 6 次')" == 'Executed 6 times' ]]
[[ "$(ui_text '不可用 · 缺少 brutal 内核模块')" == 'Unavailable · Missing brutal kernel module' ]]
for mode in en zh; do
  UI_LANGUAGE="$mode"
  for terminal_mode in plain dumb no-color; do
    (
      case "$terminal_mode" in
        plain) unset NO_COLOR; export TERM=xterm ;;
        dumb) unset NO_COLOR; export TERM=dumb ;;
        no-color) export NO_COLOR=1 TERM=xterm ;;
      esac
      source "$SCRIPT"
      system_summary() { printf 'Debian GNU/Linux 13 (trixie) · amd64 · Kernel 6.12.57+deb13-amd64'; }
      local_core_version() { printf 1.13.18; }
      local_cloudflared_version() { printf 2026.7.3; }
      SCRIPT_RUNS_REQUESTED=1 SCRIPT_RUNS_TOTAL=6 SCRIPT_RUNS_SHOWN=0
      control_panel
      brand 'Argo-Singbox · 控制中心' main
      state_value '节点概览' 'VLESS 1 · VMess 2 · Trojan 1'
      state_value 'WARP 分流' "$(warp_status)"
      ip_value 'VPS IPv6' None
      component_version_value
      menu_item 11 '语言设置'
      ui_warn '提醒'; ui_err '错误'; ui_info '当前状态'
    ) >"$TEST_DIR/$mode-$terminal_mode" 2>"$TEST_DIR/$mode-$terminal_mode.err"
    ! grep -q $'\033' "$TEST_DIR/$mode-$terminal_mode" "$TEST_DIR/$mode-$terminal_mode.err"
    grep -Fq '6.12.57+deb13-amd64' "$TEST_DIR/$mode-$terminal_mode"
    grep -Fq 'AGS 2026.10.07 · Sing-box 1.13.18 · cloudflared 2026.7.3' "$TEST_DIR/$mode-$terminal_mode"
    ! grep -q '全局累计' "$TEST_DIR/$mode-$terminal_mode"
  done
  if [[ "$mode" == en ]]; then
    grep -Fq 'Executed 6 times' "$TEST_DIR/$mode-plain"
    grep -Fq 'Enter · Default | 0 · Exit' "$TEST_DIR/$mode-plain"
    ! grep -P '[\x{4E00}-\x{9FFF}]' "$TEST_DIR/$mode-plain" "$TEST_DIR/$mode-plain.err"
  else
    grep -Fq 'Executed 6 times' "$TEST_DIR/$mode-plain"
    grep -Fq 'Enter · 默认 | 0 · 退出' "$TEST_DIR/$mode-plain"
  fi
done
UI_LANGUAGE=en
local_core_version() { printf 1.13.18; }
local_cloudflared_version() { printf 2026.7.3; }
C_BRIGHT_YELLOW=yellow C_BRIGHT_RED=red C_BRIGHT_GREEN=green C_BRIGHT_MAGENTA=purple C_RESET=reset
[[ "$(state_value '节点概览' 'VLESS 1 · VMess 2 · Trojan 1')" == *purple* ]]
[[ "$(state_value WARP 'Enabled · Running')" == *green* ]]
[[ "$(state_value WARP 'Enabled · Error: process not running')" == *red* ]]
[[ "$(component_version_value)" == *yellow*2026.10.07*yellow*1.13.18* ]]
printf 'LANGUAGE_SMOKE_OK\n'
