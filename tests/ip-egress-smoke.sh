#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/argo-singbox.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
ip() { printf '%s\n' 'default dev eth0 src 192.0.2.1'; }
curl() {
  printf '%s\n' "$*" >>"$TEST_DIR/curl.log"
  [[ "$*" == *"https://get.geojs.io/v1/ip/geo.json"* && "$*" == *"--noproxy *"* ]] || return 1
  if [[ "$1" == -4fsS ]]; then
    [[ "${TEST_V4:-1}" == 1 ]] || return 1
    printf '{"ip":"107.173.211.29","country_code":"US","asn":36352,"organization_name":"HostPapa"}'
  else
    [[ "${TEST_V6:-1}" == 1 ]] || return 1
    printf '{\n "ip": "2001:db8::29",\n "country_code": "US",\n "asn": 36352,\n "organization_name": "HostPapa"\n}\n'
  fi
}
detect_public_ips
[[ "$PUBLIC_IPV4" == 107.173.211.29 && "$PUBLIC_IPV6" == 2001:db8::29 ]]
[[ "$(public_ipv4_details)" == '107.173.211.29|US|AS36352|HostPapa' ]]
PUBLIC_IPV4_JSON='{"ip":"107.173.211.29","country_code":"US","asn":36352,"organization_name":"AS36352 HostPapa"}'
[[ "$(public_ipv4_details)" == '107.173.211.29|US|AS36352|HostPapa' ]]
[[ "$(direct_strategy)" == prefer_ipv4 ]]
detect_public_ips
[[ "$(wc -l <"$TEST_DIR/curl.log")" -eq 2 ]]
select_node_egress '' <<<'' >/dev/null
[[ "$NODE_EGRESS" == direct:ipv4 ]]
select_node_egress '' <<<6 >/dev/null
[[ "$NODE_EGRESS" == direct:ipv6 ]]
(select_node_egress '' <<<0; printf 'CANCEL_FAILED\n') >"$TEST_DIR/cancel-selection.log"
! grep -q CANCEL_FAILED "$TEST_DIR/cancel-selection.log"
if (select_node_egress '' <<<5 >/dev/null 2>&1); then exit 1; fi
NODES_CONFIG="$TEST_DIR/nodes.conf"
STATS_API_PORT=18085
printf 'Test|vless|/test|3011|\n' >"$NODES_CONFIG"
begin_config_change() { touch "$TEST_DIR/changed"; }
apply_runtime_config() { touch "$TEST_DIR/applied"; }
edit_node_profile >"$TEST_DIR/edit.log" <<'EOF'
Test





6
EOF
[[ "$(cat "$NODES_CONFIG")" == 'Test|vless|/test|3011|direct:ipv6' ]]
[[ -f "$TEST_DIR/changed" && -f "$TEST_DIR/applied" ]]
rm -f "$TEST_DIR/changed" "$TEST_DIR/applied"
(edit_node_profile; printf 'CANCEL_FAILED\n') >"$TEST_DIR/cancel.log" <<'EOF'
Test





0
EOF
! grep -q CANCEL_FAILED "$TEST_DIR/cancel.log"
[[ "$(cat "$NODES_CONFIG")" == 'Test|vless|/test|3011|direct:ipv6' ]]
[[ ! -f "$TEST_DIR/changed" && ! -f "$TEST_DIR/applied" ]]
TEST_V4=0 PUBLIC_IPS_DETECTED=0
detect_public_ips
[[ -z "$PUBLIC_IPV4" && "$PUBLIC_IPV6" == 2001:db8::29 ]]
[[ "$(direct_strategy)" == ipv6_only ]]
select_node_egress '' </dev/null >/dev/null
[[ "$NODE_EGRESS" == direct:ipv6 ]]
TEST_V6=0 PUBLIC_IPS_DETECTED=0
detect_public_ips
[[ -z "$PUBLIC_IPV4" && -z "$PUBLIC_IPV6" ]]
if (select_node_egress '' >/dev/null 2>&1); then exit 1; fi
TEST_V4=1 PUBLIC_IPS_DETECTED=0
detect_public_ips
[[ "$(direct_strategy)" == ipv4_only ]]
# Invalid API data must never become an advertised public IP.
geojs_query() { printf '{"ip":"bad","country_code":"US"}'; }
PUBLIC_IPS_DETECTED=0
detect_public_ips
[[ -z "$PUBLIC_IPV4" && -z "$PUBLIC_IPV6" ]]
printf '%s\n' IP_EGRESS_SMOKE_OK
