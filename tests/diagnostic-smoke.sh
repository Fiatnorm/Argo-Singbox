#!/usr/bin/env bash
set -Eeuo pipefail
export NO_COLOR=1 TERM=dumb UI_LANGUAGE=zh
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/argo-singbox.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
CONFIG_DIR="$TEST_DIR/config" DATA_DIR="$TEST_DIR/data" SUBSCRIPTION_DIR="$TEST_DIR/subscriptions"
mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$SUBSCRIPTION_DIR" "$TEST_DIR/systemd"
NODES_CONFIG="$CONFIG_DIR/nodes.conf" NODES_FILE="$DATA_DIR/nodes.txt"
printf 'One|vless|/one|3011|\nTwo|vmess|/two|3012|\nThree|trojan|/three|3013|\n' >"$NODES_CONFIG"
ARGO_TOKEN=fixture-token UUID=11111111-1111-4111-8111-111111111111
ARGO_DOMAIN=example.com SERVER=example.com SERVER_PORT=443 ORIGIN_PORT=3010 STATS_API_PORT=18085
WARP_ENABLED=0 WARP_PROXY_PORT=40000 WARP_DOMAINS=example.com WARP_GEOSITES=""
MULTIPLEX_ENABLED=1 TCP_BRUTAL_ENABLED=1
BRUTAL_UP_MBPS=1000 BRUTAL_DOWN_MBPS=1000
printf 'ExecStart=cloudflared --token %s\n' "$ARGO_TOKEN" >"$TEST_DIR/systemd/${ARGO_SERVICE}.service"
# Map only the service-file fixture path; exercise the actual doctor and health checks.
definition="$(declare -f doctor)"
definition="${definition//\/etc\/systemd\/system/$TEST_DIR/systemd}"
eval "$definition"
require_root() { :; }; load_env() { :; }; ensure_nodes_config() { :; }
detect_public_ips() { :; }
public_ipv4_details() { printf '107.173.211.29|US|AS36352|HostPapa'; }
public_ipv6_details() { return 1; }
read_traffic_totals() { printf '1024|2048'; }
runtime_memory_usage() { printf '56.8 MiB'; }
local_core_version() { printf '1.14.3'; }; local_cloudflared_version() { printf '2026.10.0'; }
service_status() { printf '已启用 · 运行中'; }
traffic_timer_status() { printf '已启用 · 每分钟'; }
warp_status() { printf '未启用 · 可选功能'; }
validate_nodes_config() { :; }; valid_uuid() { :; }; valid_argo_token() { :; }
core_check() { [[ "$SCENARIO" != mixed ]]; }
nginx() { :; }
stat() { [[ "${*: -1}" == "$SUBSCRIPTION_DIR" ]] && printf 755 || printf 700; }
detect_tcp_brutal() { IS_BRUTAL=true; [[ "$SCENARIO" != mixed ]] || IS_BRUTAL=false; }
systemctl() {
  [[ "$1" == is-active ]] || return 0
  [[ "$SCENARIO" != warp-failed || "${*: -1}" != warp-svc ]] || return 1
  [[ "$SCENARIO" != mixed || ( "${*: -1}" != "$CORE_SERVICE" && "${*: -1}" != "${TRAFFIC_TIMER}.timer" ) ]]
}
traffic_collect() { [[ "$SCENARIO" != mixed ]] || exit 1; }
ss() { [[ "$SCENARIO" != mixed || "$*" != *':3011'* ]] && printf 'LISTEN\n'; }
curl() {
  if [[ "$*" == *--socks5-hostname* ]]; then [[ "$SCENARIO" != warp-failed ]]; return; fi
  if [[ "$SCENARIO" == mixed && "${*: -1}" == */one ]]; then printf 'HTTP/1.1 403 Forbidden\r\n'; return; fi
  if [[ "$SCENARIO" == mixed && "${*: -1}" == */two ]]; then return 28; fi
  printf 'HTTP/1.1 101 Switching Protocols\r\n'
}
journalctl() {
  touch "$TEST_DIR/unexpected-journal"
  return 1
}
for UI_LANGUAGE in zh en; do
  for SCENARIO in healthy mixed warp-healthy warp-failed; do
    WARP_ENABLED=0
    [[ "$SCENARIO" != warp-* ]] || WARP_ENABLED=1
    result=0
    doctor >"$TEST_DIR/output" 2>"$TEST_DIR/errors" || result=$?
    cat "$TEST_DIR/errors" >>"$TEST_DIR/output"
    [[ ( "$SCENARIO" == mixed || "$SCENARIO" == warp-failed ) && "$result" == 1 ||
      ( "$SCENARIO" == healthy || "$SCENARIO" == warp-healthy ) && "$result" == 0 ]]
    if [[ "$UI_LANGUAGE" == zh ]]; then
      mapfile -t headings < <(grep '^▸ ' "$TEST_DIR/output")
      [[ "${headings[*]}" == '▸ 运行状态 ▸ 配置检查 ▸ 服务状态 ▸ 诊断结果' ]]
      awk '/^▸ 配置检查$/ {exit} {print}' "$TEST_DIR/output" >"$TEST_DIR/status"
      ! grep -E '^(Argo Tunnel|Sing-box Core|流量采集|WARP 分流|h2mux|TCP Brutal|系统内存) ' "$TEST_DIR/status"
      awk '/^▸ 配置检查$/ {show=1; next} /^▸ 服务状态$/ {exit} show {print}' "$TEST_DIR/output" >"$TEST_DIR/config-output"
      awk '/^▸ 服务状态$/ {show=1; next} /^▸ 诊断结果$/ {exit} show {print}' "$TEST_DIR/output" >"$TEST_DIR/services"
      ! grep -Fq WARP "$TEST_DIR/services"
      if [[ "$SCENARIO" != warp-failed ]]; then grep -Fq WARP "$TEST_DIR/config-output"; fi
      case "$SCENARIO" in
        healthy|warp-healthy) grep -Fq '诊断完成 · 0 个错误 · 0 个提醒' "$TEST_DIR/output" ;;
        mixed) grep -Fq '诊断完成 · 6 个错误 · 2 个提醒' "$TEST_DIR/output" ;;
        warp-failed) grep -Fq '诊断完成 · 2 个错误 · 0 个提醒' "$TEST_DIR/output" ;;
      esac
    else
      ! grep -P '[\x{4E00}-\x{9FFF}]' "$TEST_DIR/output"
      [[ "$(grep -c '^▸ ' "$TEST_DIR/output")" -eq 4 ]]
    fi
    ! grep -q $'\033' "$TEST_DIR/output"
    ! grep -q '安装完成' "$TEST_DIR/output"
    grep -Fq 'Sing-box 1.14.3 · cloudflared 2026.10.0' "$TEST_DIR/output"
    grep -Fq "$NODES_FILE" "$TEST_DIR/output"
    [[ ! -f "$TEST_DIR/unexpected-journal" ]]
  done
done
# Numeric memory and both command names are purple; separator keeps its original color.
C_BRIGHT_MAGENTA=PURPLE C_BRIGHT_WHITE=WHITE C_RESET=RESET
[[ "$(key_value '运行内存' '461.1 MiB')" == *'PURPLE461.1 MiBRESET'* ]]
[[ "$(key_value '管理命令' 'ags / AGS')" == *'PURPLEagsWHITE / PURPLEAGSRESET'* ]]
printf 'DIAGNOSTIC_SMOKE_OK\n'
