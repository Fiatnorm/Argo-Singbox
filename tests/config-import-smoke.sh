#!/usr/bin/env bash
set -Eeuo pipefail
export UI_LANGUAGE=zh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../argo-singbox.sh
source "${ROOT_DIR}/argo-singbox.sh"

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

UUID="11111111-1111-4111-8111-111111111111"
ARGO_DOMAIN="old.example.com"
SERVER="old.example.com"
SERVER_PORT=8443
ARGO_TOKEN="old-token"
ORIGIN_PORT=3010
WARP_ENABLED=0
WARP_PROXY_PORT=40000
WARP_DOMAINS=""
WARP_GEOSITES=""
CORE="sing-box"
STATS_API_PORT=18085
BRUTAL_UP_MBPS=1000
BRUTAL_DOWN_MBPS=1000
MULTIPLEX_ENABLED=1
TCP_BRUTAL_ENABLED=1
OUTBOUND_IP_FAMILY=auto

cat >"${TEST_DIR}/valid.env" <<'EOF'
# Argo-Singbox import fixture
UUID='22222222-2222-4222-8222-222222222222'
ARGO_DOMAIN="tunnel.example.com"
SERVER=polestar.com
ARGO_TOKEN=test-token
ORIGIN_PORT=3020
WARP_ENABLED=1
WARP_PROXY_PORT=41000
WARP_DOMAINS='example.com,openai.com'
WARP_GEOSITES='geosite:google,openai'
STATS_API_PORT=18086
BRUTAL_UP_MBPS=900
BRUTAL_DOWN_MBPS=1100
MULTIPLEX_ENABLED=1
TCP_BRUTAL_ENABLED=0
OUTBOUND_IP_FAMILY=ipv6
EOF
load_config_file "${TEST_DIR}/valid.env" >/dev/null
[[ "$UUID" == "22222222-2222-4222-8222-222222222222" ]]
[[ "$ARGO_DOMAIN" == "tunnel.example.com" ]]
[[ "$SERVER" == "polestar.com" && "$SERVER_PORT" == "443" ]]
[[ "$WARP_GEOSITES" == "geosite:google,openai" ]]
[[ "$OUTBOUND_IP_FAMILY" == "ipv6" ]]
validate_environment
[[ "$WARP_GEOSITES" == "google,openai" ]]

cat >"${TEST_DIR}/separate-port.env" <<'EOF'
SERVER=cdn.example.com
SERVER_PORT=8443
EOF
load_config_file "${TEST_DIR}/separate-port.env" >/dev/null
[[ "$SERVER" == "cdn.example.com" && "$SERVER_PORT" == "8443" ]]

parse_endpoint "polestar.com"
[[ "$SERVER" == "polestar.com" && "$SERVER_PORT" == "443" ]]
parse_endpoint "1.1.1.1:8443"
[[ "$SERVER" == "1.1.1.1" && "$SERVER_PORT" == "8443" ]]
parse_endpoint "[2001:db8::1]"
[[ "$SERVER" == "2001:db8::1" && "$SERVER_PORT" == "443" ]]
parse_endpoint "[2001:db8::1]:2053"
[[ "$SERVER" == "2001:db8::1" && "$SERVER_PORT" == "2053" ]]

cat >"${TEST_DIR}/unknown.env" <<'EOF'
UNSAFE_KEY=value
EOF
if (load_config_file "${TEST_DIR}/unknown.env" >/dev/null 2>&1); then
  printf 'unknown import key unexpectedly accepted\n' >&2
  exit 1
fi

OUTBOUND_IP_FAMILY=invalid
if (validate_environment >/dev/null 2>&1); then
  printf 'invalid outbound IP family unexpectedly accepted\n' >&2
  exit 1
fi
OUTBOUND_IP_FAMILY=auto

injection_target="${TEST_DIR}/executed"
printf "ARGO_DOMAIN='\$(touch %s)'\n" "$injection_target" >"${TEST_DIR}/literal.env"
load_config_file "${TEST_DIR}/literal.env" >/dev/null
[[ ! -e "$injection_target" ]]

ln -s "${TEST_DIR}/valid.env" "${TEST_DIR}/linked.env"
if [[ -L "${TEST_DIR}/linked.env" ]]; then
  if (load_config_file "${TEST_DIR}/linked.env" >/dev/null 2>&1); then
    printf 'symlink import unexpectedly accepted\n' >&2
    exit 1
  fi
fi
if (parse_endpoint "999.1.1.1" >/dev/null 2>&1); then
  printf 'invalid IPv4 unexpectedly accepted\n' >&2
  exit 1
fi

printf '%s\n' 'CONFIG_IMPORT_SMOKE_OK'
