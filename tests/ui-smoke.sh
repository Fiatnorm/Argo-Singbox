#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NO_COLOR=1 TERM=dumb
source "${ROOT_DIR}/argo-singbox.sh"
system_summary() { printf 'Debian · amd64 · Kernel 6.12'; }
output="$(control_panel)"
[[ "$output" != *$'\033'* ]]
while IFS= read -r line; do
  (( $(display_width "$line") <= 64 )) || { printf 'overwide: %s\n' "$line"; exit 1; }
done <<<"$output"
[[ "$(grep -c '^' <<<"$output" | tr -d ' ')" -ge 10 ]]
! grep -q '____' <<<"$output"
for mode in 'TERM=dumb' 'NO_COLOR=1' ; do
  output="$(env $mode bash -c 'source "$1"; control_panel' _ "$ROOT_DIR/argo-singbox.sh")"
  [[ "$output" != *$'\033'* ]]
done
service_status() { printf '已启用 · 运行中'; }
warp_status() { printf '未启用 · 可选功能'; }
detect_tcp_brutal() { IS_BRUTAL=true; }
read_traffic_totals() { printf '26091926323|187904819200'; }
detect_public_ips() { PUBLIC_IPV4=107.173.211.29; PUBLIC_IPV6=2001:db8::29; }
public_ipv4_details() { printf '107.173.211.29|US|AS36352|HostPapa'; }
runtime_memory_usage() { printf '96.0 MiB'; }
local_core_version() { printf 1.13.18; }
local_cloudflared_version() { printf 2026.7.3; }
ARGO_DOMAIN=example.com SERVER=polestar.com SERVER_PORT=443
BRUTAL_UP_MBPS=1000 BRUTAL_DOWN_MBPS=1000
output="$(runtime_overview)"
previous=0
for label in 'Argo Tunnel' 'Sing-box Core' 'WARP 分流' h2mux 'TCP Brutal' '节点概览' 'Argo 域名' '优选入口' 'Argo 回源' 'VPS IPv4' 'VPS IPv6' '全局流量' '运行内存' '项目版本' '组件版本'; do
  current="$(grep -n "^$label " <<<"$output" | cut -d: -f1)"
  ((current > previous)); previous="$current"
done
while IFS= read -r line; do (( $(display_width "$line") <= 64 )); done <<<"$output"
[[ "$output" != *'AS36352 · AS36352'* && "$output" != *$'\033'* ]]
for mode in main back default none cancel; do
  page="$(ui_page 'Argo-Singbox · 控制中心' "$mode")"
  [[ "$page" == *'Enter · 默认 | 0 · 取消'* ]]
  while IFS= read -r line; do (( $(display_width "$line") <= 64 )); done <<<"$page"
done
C_BRIGHT_YELLOW=$'\033[93m'; C_BRIGHT_WHITE=$'\033[97m'; C_RESET=$'\033[0m'
page="$(ui_page 'Argo-Singbox · 控制中心')"
[[ "$page" == *$'\033[93mEnter'* && "$page" == *$'\033[93m0'* ]]
error_file="$(mktemp)"
red '测试错误' 2>"$error_file"
[[ "$(cat "$error_file")" != *$'\033'* ]]
rm -f "$error_file"
printf '%s\n' UI_SMOKE_OK
