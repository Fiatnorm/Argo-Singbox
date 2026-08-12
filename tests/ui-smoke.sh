#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NO_COLOR=1 TERM=dumb
# shellcheck source=../argo-singbox.sh
source "${ROOT_DIR}/argo-singbox.sh"

uname() {
  case "${1:-}" in
    -m) printf '%s\n' 'x86_64' ;;
    -r) printf '%s\n' '6.12.101+deb13-amd64' ;;
    *) command uname "$@" ;;
  esac
}

output="$({
  brand "Argo-Singbox · 参数配置" back
  subsection "配置维护"
  menu_item 11 "导入配置文件"
  brand "Argo-Singbox · 输入示例" default
  control_panel
  ui_line
})"
cjk_cell="$(fit_text '香港节点-超长名称' 8)"
[[ "$(display_width "$cjk_cell")" -eq 8 ]]
status_line="$(state_value '运营商' 'A very long English network operator name that must not break the status layout')"
[[ "$(display_width "$status_line")" -le 64 ]]

[[ "$output" != *$'\033'* ]]
grep -Fq 'Argo-Singbox · 参数配置' <<<"$output"
grep -Fq '导入配置文件' <<<"$output"
grep -Fq 'Enter · 默认 | 0 · 取消' <<<"$output"
grep -Fq 'Argo-Singbox  v2026.08.12 · Argo Tunnel · Sing-box Core · WSS Proxy' <<<"$output"
grep -Fq 'Kernel 6.12.101' <<<"$output"
! grep -Fq 'Kernel 6.12.101+deb13-amd64' <<<"$output"
! grep -Fq 'ArgoFusion' <<<"$output"
! grep -Eq '刷新订阅模板|完整模板' <<<"$output"
! grep -Fq 'while true' "${ROOT_DIR}/argo-singbox.sh"
! grep -Eq '(^|[[:space:]])clear([[:space:]]|$)' "${ROOT_DIR}/argo-singbox.sh"
while IFS= read -r line; do
  [[ "$line" =~ ^-+$ ]] || continue
  [[ ${#line} -eq 64 ]] || { printf 'UI divider width is %s, expected 64\n' "${#line}" >&2; exit 1; }
done <<<"$output"

service_status() { printf '%s' '已启用 · 运行中'; }
warp_status() { printf '%s' '未启用'; }
multiplex_status() { printf '%s' '已启用 · h2mux'; }
tcp_brutal_status() { printf '%s' '未启用 · 原因：缺少 brutal 内核模块'; }
public_ipv4_details() { printf '%s' '107.173.211.29|US|AS36352|HostPapa'; }
read_traffic_totals() { printf '%s' '211707494|1181116006'; }
runtime_memory_usage() { printf '%s' '12.0 MiB'; }
node_overview() { printf '%s' 'Vless 1 · Vmess 1 · Trojan 1'; }
component_versions() { printf '%s' 'AGS 2026.08.12 · Sing-box 1.13.18 · CF 2026.7.3'; }
ARGO_DOMAIN=""
runtime_output="$(runtime_overview)"
grep -Fq 'VPS IPv4       107.173.211.29 · US · AS36352 · HostPapa' <<<"$runtime_output"
! grep -Eq '^国家|^ASN|^运营商' <<<"$runtime_output"
grep -Fq '流量统计       Total Upload 201.9 MiB · Total Download 1.1 GiB' <<<"$runtime_output"
grep -Fq '运行内存       12.0 MiB' <<<"$runtime_output"
! grep -Fq '脚本内存' <<<"$runtime_output"
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  (( $(display_width "$line") <= 64 )) || { printf 'runtime line exceeds 64 columns: %s\n' "$line" >&2; exit 1; }
done <<<"$runtime_output"

read_choice() { REPLY=0; }
WARP_ENABLED=0
WARP_PROXY_PORT=40000
WARP_DOMAINS=""
WARP_GEOSITES=""
warp_menu_output="$(configure_warp)"
grep -Fq '域名管理' <<<"$warp_menu_output"
grep -Fq 'geosite 分类' <<<"$warp_menu_output"
! grep -Eq '添加域名|删除域名' <<<"$warp_menu_output"
warp_domain_output="$(configure_warp_domains)"
grep -Fq '添加域名' <<<"$warp_domain_output"
grep -Fq '删除域名' <<<"$warp_domain_output"

NODE_LIST_CALLED=0
brand() { :; }
section() { :; }
list_node_profiles() { NODE_LIST_CALLED=1; }
next_node_port() { printf '%s' '3011'; }
read_input() { printf -v "$2" '%s' '0'; }
add_node_profile
[[ "$NODE_LIST_CALLED" == "1" ]]

printf '%s\n' 'UI_SMOKE_OK'
