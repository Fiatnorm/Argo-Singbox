#!/usr/bin/env bash
set -Eeuo pipefail
export UI_LANGUAGE=zh NO_COLOR=1 TERM=dumb
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/argo-singbox.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
NODES_CONFIG="$TEST_DIR/nodes.conf"
cat >"$NODES_CONFIG" <<'EOF'
Default|vless|/one|3011|
IPv4|vmess|/two|3012|direct:ipv4
IPv6|trojan|/three|3013|direct:ipv6
Socks|vmess|/four|3014|socks5://user:pass@192.0.2.123:1080
Long-node-label-123456789|vless|/long-path-1234567890|3015|http://user:pass@proxy.example.com:8080
EOF
detect_public_ips() { PUBLIC_IPV4=107.173.211.29; PUBLIC_IPV6=2001:db8::1234; }
public_node_egress_ip() { printf 107.173.211.29; }
list_node_profiles >"$TEST_DIR/list"
[[ "$(grep -c 'Direct · 107.173.211.29' "$TEST_DIR/list")" == 2 ]]
grep -Fq 'Direct · 2001:db8::1234' "$TEST_DIR/list"
grep -Fq 'SOCKS5 · 192.0.2.123' "$TEST_DIR/list"
grep -Fq 'HTTP · proxy.example.com' "$TEST_DIR/list"
grep -Fq 'Long-node-label-123456789' "$TEST_DIR/list"
grep -Fq '/long-path-1234567890' "$TEST_DIR/list"
! grep -Eq '~|user|pass|IPv4 · direct' "$TEST_DIR/list"
! grep -q $'\033' "$TEST_DIR/list"
C_BRIGHT_MAGENTA=PURPLE C_RESET=RESET
read_input '优选入口 [example.com:443]：' endpoint <<< '1.1.1.1:443' >"$TEST_DIR/prompt"
[[ "$endpoint" == 1.1.1.1:443 ]]
[[ "$(cat "$TEST_DIR/prompt")" == *RESETPURPLERESET ]]
C_BRIGHT_MAGENTA='' C_RESET=''
require_root() { :; }
C_UNDERLINE=UNDER
manage_bbr <<< n >"$TEST_DIR/tools"
grep -Fq 'UNDERhttps://github.com/ylx2016/Linux-NetSpeed' "$TEST_DIR/tools"
(configure_warp_geosites <<< 0) >"$TEST_DIR/geosite"
grep -Fq 'https://geosite-explorer.pages.dev/' "$TEST_DIR/geosite"
C_UNDERLINE=''
ensure_nodes_config() { :; }
systemctl() { return 0; }
traffic_collect() { return 0; }
ss() { printf LISTEN; }
curl() { printf 'HTTP/1.1 101 Switching Protocols\r\n'; }
ORIGIN_PORT=3010 STATS_API_PORT=18085 ARGO_DOMAIN=example.com SERVER=example.com SERVER_PORT=443
for mode in full diagnostic; do
  health_check "$mode" >"$TEST_DIR/health"
  grep -Fq '✓ 端口检测： 本地端口监听正常。' "$TEST_DIR/health"
  awk '/Clash API/ {api=NR} /端口检测/ {port=NR} /\/one：/ {ws=NR} END {exit !(api < port && port < ws)}' "$TEST_DIR/health"
  [[ "$HEALTH_CHECK_ERRORS" == 0 ]]
done
printf 'requested UI smoke: ok\n'
