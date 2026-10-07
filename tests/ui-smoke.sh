#!/usr/bin/env bash
set -Eeuo pipefail
export UI_LANGUAGE=zh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${ROOT_DIR}/argo-singbox.sh"
OUTPUT="$(mktemp)"
STATUS_OUTPUT="$(mktemp)"
EXIT_OUTPUT="$(mktemp)"
trap 'rm -f "$OUTPUT" "$STATUS_OUTPUT" "$EXIT_OUTPUT"' EXIT

NO_COLOR=1 TERM=dumb bash -c '
  source "$1"
  brand "Argo-Singbox · 配置中心" back
  brand "Argo-Singbox · 控制中心" main
  control_panel
  section "当前状态"
  state_value "Sing-box Core" "已启用 · 运行中"
  state_value "WARP 分流" "未启用 · 可选功能"
  state_value "h2mux" "已启用 · 16 streams · padding"
  menu_item 1 "节点订阅" "ags -n"
  menu_item 2 "配置中心" "ags -c"
  menu_item 0 "退出脚本"
  ui_line
  prompt "请选择："
' _ "$SCRIPT" >"$OUTPUT" 2>&1

if LC_ALL=C grep -q $'\033' "$OUTPUT"; then
  printf 'TERM=dumb output contains ANSI escape sequences\n' >&2
  exit 1
fi

while IFS= read -r line; do
  width="$(NO_COLOR=1 TERM=dumb bash -c 'source "$1"; display_width "$2"' _ "$SCRIPT" "$line")"
  [[ "$line" == Argo-Singbox*WSS\ Proxy || "$line" == 系统环境* ]] || ((width <= 64)) || {
    printf 'UI line exceeds 64 columns (%s): %s\n' "$width" "$line" >&2
    exit 1
  }
done <"$OUTPUT"

NO_COLOR=1 TERM=dumb bash -c '
  source "$1"
  read_traffic_totals() { printf "1024|2048"; }
  service_status() { printf "已启用 · 运行中"; }
  warp_status() { printf "未启用 · 可选功能"; }
  multiplex_status() { printf "已启用 · 16 streams · padding"; }
  tcp_brutal_status() { printf "已启用 · 1000/1000 Mbps"; }
  node_overview() { printf "VLESS 1 · VMess 2 · Trojan 1"; }
  public_ipv4_details() { printf "192.0.2.1|US|AS64500|Example ISP"; }
  public_ipv6_details() { printf "2001:db8::1|US|AS64500|Example ISP"; }
  runtime_memory_usage() { printf "56.8 MiB"; }
  ARGO_DOMAIN="example.com"; SERVER="polestar.com"; SERVER_PORT=443; ORIGIN_PORT=3010; OUTBOUND_IP_FAMILY=ipv4
  runtime_overview
' _ "$SCRIPT" >"$STATUS_OUTPUT"

previous_line=0
for label in 'Argo Tunnel' 'Sing-box Core' 'WARP 分流' h2mux 'TCP Brutal' '节点概览' 'Argo 域名' '优选入口' 'Argo 回源' 'VPS IPv4' 'VPS IPv6' '全局流量' '运行内存' '组件版本'; do
  line="$(grep -n "^${label}[[:space:]]" "$STATUS_OUTPUT" | head -n 1 | cut -d: -f1)"
  [[ "$line" =~ ^[0-9]+$ && "$line" -gt "$previous_line" ]] || {
    printf 'runtime status order is wrong at: %s\n' "$label" >&2
    exit 1
  }
  previous_line="$line"
done
! grep -Eq '^_{5,}' "$OUTPUT"

grep -Fq 'Argo-Singbox · 配置中心' "$OUTPUT"
grep -Fq 'Enter · 默认 | 0 · 退出' "$OUTPUT"
while IFS= read -r logo_line; do
  grep -Fq -- "$logo_line" "$OUTPUT"
done <<'LOGO'
    ___                     _____ _             __
   /   |  _________ _____  / ___/(_)___  ____ _/ /_  ____  _  __
  / /| | / ___/ __ `/ __ \ \__ \/ / __ \/ __ `/ __ \/ __ \| |/_/
 / ___ |/ /  / /_/ / /_/ /___/ / / / / / /_/ / /_/ / /_/ />  <
/_/  |_/_/   \__, /\____//____/_/_/ /_/\__, /_.___/\____/_/|_|
            /____/                    /____/
LOGO
! grep -Fxq 'Argo-Singbox' "$OUTPUT"
grep -Fq 'Sing-box Core' "$OUTPUT"
grep -Fq 'WARP 分流' "$OUTPUT"
grep -Fq 'h2mux' "$OUTPUT"
grep -Fq '› 请选择：' "$OUTPUT"

for required in \
  '常用操作' '运行观测' '系统维护' '项目管理' \
  '节点订阅' '配置中心' '服务管理' '流量统计' '运行诊断' \
  '组件更新' '备份恢复' '系统工具' '项目安装' '项目卸载' \
  'WARP 开关' '分流规则' '域名规则' 'geosite 规则' \
  '节点落地 IP' 'IPv4 直连出站' 'IPv6 直连出站' \
  '启用 h2mux' '停用 h2mux' '设置 Brutal 带宽' \
  'Argo 回源' 'Token / 域名' '节点代理 [http:// 或 socks5://user:pass@host:port；留空为 direct]' \
  '状态报告' '诊断完成 · 0 个错误 · 0 个提醒' \
  '不可用 · 缺少 brutal 内核模块' '创建备份' '恢复配置' \
  '重启核心服务' '近期错误日志' '出站'; do
  grep -Fq "$required" "$SCRIPT" || {
    printf 'missing UI contract text: %s\n' "$required" >&2
    exit 1
  }
done

if grep -Eq '代理核心|Vless|Vmess|Warp|自动适配 QR|启用配置|\[Y/n\]' "$SCRIPT"; then
  printf 'legacy terminal wording remains in script\n' >&2
  exit 1
fi

grep -Fq '输入 REMOVE 确认卸载：' "$SCRIPT"
grep -Fq 'is_confirmed() { [[ "${1:-}" =~ ^[Yy]$ ]]; }' "$SCRIPT"
! grep -Eq '(^|[[:space:]])clear([[:space:];]|$)' "$SCRIPT"
! grep -Eq '^menu\(\).*while true' "$SCRIPT"

NO_COLOR=1 TERM=xterm bash -c '
  source "$1"
  [[ -z "$C_RESET$C_BRIGHT_GREEN$C_BRIGHT_RED$C_ERR_RESET$C_ERR_RED" ]]
  ! is_confirmed ""
  is_confirmed y
  is_confirmed Y
  printf "\\n" | { read_choice "请选择："; [[ "$REPLY" == 0 ]]; }
' _ "$SCRIPT"

NO_COLOR=1 TERM=dumb bash -c '
  source "$1"
  if [[ -r "/proc/$$/status" ]]; then
    sleep 30 & service_pid=$!
    trap "kill $service_pid 2>/dev/null || true" EXIT
    systemctl() {
      if [[ "$4" == ControlGroup ]]; then return 0; fi
      if [[ "$4" == MainPID && "$2" == "$CORE_SERVICE" ]]; then printf "%s\\n" "$service_pid"; else printf "0\\n"; fi
    }
    self_rss="$(awk "/^VmRSS:/{print \$2; exit}" "/proc/$$/status")"
    service_rss="$(awk "/^VmRSS:/{print \$2; exit}" "/proc/$service_pid/status")"
    baseline="$(format_traffic_bytes "$((self_rss * 1024))")"
    actual="$(runtime_memory_usage)"
    [[ "$service_rss" =~ ^[0-9]+$ && "$actual" != "$baseline" ]]
  fi
' _ "$SCRIPT"

if NO_COLOR=1 TERM=dumb bash -c 'source "$1"; is_exit_input 0; printf "did not exit\\n"' _ "$SCRIPT" | grep -q .; then
  printf '0 input did not exit the script\n' >&2
  exit 1
fi

grep -Fq 'menu_item 0 "退出脚本"' "$SCRIPT"
! grep -Fq 'menu_item 0 "返回上级"' "$SCRIPT"
! grep -Eq '^[[:space:]]*0\)[[:space:]]+return([[:space:]]|;)' "$SCRIPT"

NO_COLOR=1 TERM=dumb bash -c '
  source "$1"
  curl() {
    case "$*" in
      *-4*get.geojs.io/v1/ip/geo.json*) printf "{\"ip\":\"107.173.211.29\",\"country_code\":\"US\",\"asn\":36352,\"organization_name\":\"HostPapa\"}" ;;
      *-6*get.geojs.io/v1/ip/geo.json*) printf "{\"ip\":\"2001:db8::1\",\"country_code\":\"US\",\"asn\":64500,\"organization\":\"Example ISP\"}" ;;
      *) return 1 ;;
    esac
  }
  result="$(public_ipv4_details)"
  [[ "$result" == "107.173.211.29|US|AS36352|HostPapa" ]]
  result="$(public_ipv6_details)"
  [[ "$result" == "2001:db8::1|US|AS64500|Example ISP" ]]
  OUTBOUND_IP_FAMILY=auto
  [[ "$(effective_outbound_ip_family)" == ipv4 ]]
  public_ipv4_details() { return 1; }
  [[ "$(effective_outbound_ip_family)" == ipv6 ]]
  OUTBOUND_IP_FAMILY=ipv6
  [[ "$(public_node_egress_ip)" == "2001:db8::1" ]]
' _ "$SCRIPT"
! grep -Eq 'ipapi\.co|ip\.cloudflare\.now\.cc|api\.ipify\.org' "$SCRIPT"

NO_COLOR=1 TERM=dumb bash -c '
  source "$1"
  public_ipv4_details() { printf "192.0.2.1|US|AS64500|Example ISP"; }
  public_ipv6_details() { printf "2001:db8::1|US|AS64500|Example ISP"; }
  begin_config_change() { :; }
  apply_runtime_config() { :; }
  OUTBOUND_IP_FAMILY=auto
  configure_node_egress <<EOF
2
EOF
  [[ "$OUTBOUND_IP_FAMILY" == ipv6 ]]
' _ "$SCRIPT" >"$OUTPUT"
grep -Fq 'IPv4（默认）' "$OUTPUT"
grep -Fq 'IPv6 直连出站' "$OUTPUT"

if bash "$SCRIPT" --invalid >/dev/null 2>"$EXIT_OUTPUT"; then
  printf 'invalid command unexpectedly succeeded\n' >&2
  exit 1
fi
bash "$SCRIPT" --invalid >"$OUTPUT" 2>/dev/null || true
[[ "$(tail -c 1 "$OUTPUT" | od -An -t x1 | tr -d '[:space:]')" == "0a" ]]
[[ "$(wc -c <"$OUTPUT")" -eq 1 ]]

grep -Fq 'menu_item 3 "域名规则"' "$SCRIPT"
grep -Fq 'menu_item 4 "geosite 规则"' "$SCRIPT"
grep -Fq 'menu_item 5 "启用 h2mux"' "$SCRIPT"
grep -Fq 'menu_item 6 "停用 h2mux"' "$SCRIPT"
grep -Fq 'menu_item 4 "设置 Brutal 带宽"' "$SCRIPT"
grep -Fq 'if [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]' "$SCRIPT"
grep -Fq 'ui_err() { printf' "$SCRIPT"
grep -Fq '>&2;' "$SCRIPT"

NO_COLOR=1 TERM=dumb bash -c '
  source "$1"
  C_BRIGHT_YELLOW=yellow C_BRIGHT_RED=red C_BRIGHT_GREEN=green C_BRIGHT_MAGENTA=purple C_BRIGHT_WHITE=white C_BRIGHT_CYAN=cyan C_RESET=reset
  state="$(state_value "Argo Tunnel" "已启用 · 运行中")"
  warning_state="$(state_value "WARP 分流" "未启用 · 可选功能")"
  warning="$(ui_warn "提醒")"
  menu="$(menu_item 1 "节点订阅")"
  version="$(component_version_value)"
  nodes="$(state_value "节点概览" "VLESS 1 · VMess 2 · Trojan 1")"
  page="$(ui_page "页面" default)"
  [[ "$state" == *green* && "$warning_state" == *yellow* && "$warning" == *yellow* && "$menu" == *yellow* && "$version" == *yellow* && "$nodes" == *purple* ]]
  [[ "$page" == *"yellowEnterreset · white默认reset | yellow0reset · white退出reset"* ]]
  error="$(state_value "检查" "失败")"
  [[ "$error" == *red* ]]
' _ "$SCRIPT"

printf 'ui smoke tests passed\n'
