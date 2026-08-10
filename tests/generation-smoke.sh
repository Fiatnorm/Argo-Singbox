#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../ags.sh
source "${ROOT_DIR}/ags.sh"

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

WORK_DIR="${TEST_DIR}/work"
CONFIG_DIR="${WORK_DIR}/config"
DATA_DIR="${WORK_DIR}/data"
SUBSCRIPTION_DIR="${WORK_DIR}/subscriptions"
ENV_FILE="${CONFIG_DIR}/ags.env"
SING_BOX_CONFIG="${CONFIG_DIR}/sing-box.json"
NGINX_CONFIG="${TEST_DIR}/ags.conf"
NODES_FILE="${DATA_DIR}/nodes.txt"
NODES_CONFIG="${CONFIG_DIR}/nodes.conf"
SUB_FILE="${SUBSCRIPTION_DIR}/subscription.txt"
SUB_BASE64_FILE="${SUBSCRIPTION_DIR}/subscription.base64"
SUB_CLASH_FILE="${SUBSCRIPTION_DIR}/subscription.clash.yaml"
SUB_SING_BOX_FILE="${SUBSCRIPTION_DIR}/subscription.sing-box.json"
SUB_AUTO_QR_FILE="${SUBSCRIPTION_DIR}/subscription.auto.svg"
BIN_DIR="${WORK_DIR}/bin"

UUID="11111111-1111-4111-8111-111111111111"
ARGO_DOMAIN="example.com"
SERVER="best.example.com"
SERVER_PORT=443
ARGO_TOKEN="test-token"
ORIGIN_PORT=3010
WARP_ENABLED=0
WARP_PROXY_PORT=40000
WARP_DOMAINS=""
CORE="sing-box"
STATS_API_PORT=18085
BRUTAL_UP_MBPS=800
BRUTAL_DOWN_MBPS=1200

ensure_project_layout() {
  mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$SUBSCRIPTION_DIR"
}
sing_box_check() {
  node -e 'const f=require("fs");JSON.parse(f.readFileSync(process.argv[1],"utf8"))' "$2"
}
qrencode() {
  local output=""
  while (($#)); do
    if [[ "$1" == "-o" ]]; then output="$2"; shift 2; else shift; fi
  done
  printf '%s\n' '<svg xmlns="http://www.w3.org/2000/svg"/>' >"$output"
}
detect_tcp_brutal() { IS_BRUTAL=true; }

ensure_project_layout
mkdir -p "$BIN_DIR"
: >"${BIN_DIR}/sing-box"
chmod 755 "${BIN_DIR}/sing-box"
ensure_nodes_config
validate_nodes_config
write_sing_box_config
generate_nodes

node - "$SING_BOX_CONFIG" <<'NODE'
const fs = require('fs');
const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (config.inbounds.length !== 3) throw new Error('expected 3 inbounds');
if (config.inbounds.map(x => x.type).join(',') !== 'vless,vmess,trojan') throw new Error('unexpected inbound types');
if (config.inbounds.some(x => x.transport?.type !== 'ws')) throw new Error('all inbounds must use ws');
if (config.inbounds.some(x => x.multiplex?.enabled !== true || x.multiplex?.padding !== true)) throw new Error('server multiplex missing');
if (config.inbounds.some(x => x.multiplex?.brutal?.enabled !== true || x.multiplex?.brutal?.up_mbps !== 800 || x.multiplex?.brutal?.down_mbps !== 1200)) throw new Error('server brutal missing');
if (config.experimental?.clash_api?.external_controller !== '127.0.0.1:18085') throw new Error('missing clash api');
if (Object.keys(config.experimental).join(',') !== 'clash_api') throw new Error('unexpected experimental api');
NODE

[[ "$(wc -l <"$NODES_FILE")" -eq 3 ]]
[[ "$(grep -c '^  - {name:' "$SUB_CLASH_FILE")" -eq 3 ]]
[[ "$(grep -o 'smux: {enabled: true, protocol: h2mux' "$SUB_CLASH_FILE" | wc -l)" -eq 3 ]]
[[ "$(grep -o 'brutal-opts: {enabled: true, up: 800, down: 1200}' "$SUB_CLASH_FILE" | wc -l)" -eq 3 ]]
if command -v python >/dev/null 2>&1 && python -c 'import yaml' >/dev/null 2>&1; then
  python - "$SUB_CLASH_FILE" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as stream:
    config = yaml.safe_load(stream)
proxies = config.get("proxies", [])
if len(proxies) != 3:
    raise SystemExit("expected 3 Clash proxies")
for proxy in proxies:
    smux = proxy.get("smux", {})
    brutal = smux.get("brutal-opts", {})
    if smux.get("protocol") != "h2mux" or smux.get("max-streams") != 16:
        raise SystemExit("invalid Clash multiplex")
    if brutal != {"enabled": True, "up": 800, "down": 1200}:
        raise SystemExit("invalid Clash brutal options")
PY
fi
node - "$SUB_SING_BOX_FILE" <<'NODE'
const fs = require('fs');
const sub = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (sub.outbounds.length !== 3) throw new Error('expected 3 subscription outbounds');
if (sub.outbounds.some(x => !['vless','vmess','trojan'].includes(x.type))) throw new Error('unexpected subscription protocol');
if (sub.outbounds.some(x => x.multiplex?.protocol !== 'h2mux' || x.multiplex?.max_streams !== 16 || x.multiplex?.padding !== true)) throw new Error('subscription multiplex missing');
if (sub.outbounds.some(x => x.multiplex?.brutal?.enabled !== true || x.multiplex?.brutal?.up_mbps !== 800 || x.multiplex?.brutal?.down_mbps !== 1200)) throw new Error('subscription brutal missing');
NODE

BRUTAL_DISABLED_CONFIG="${CONFIG_DIR}/sing-box-brutal-disabled.json"
detect_tcp_brutal() { IS_BRUTAL=false; }
write_sing_box_config "$BRUTAL_DISABLED_CONFIG" "${BIN_DIR}/sing-box"
node - "$BRUTAL_DISABLED_CONFIG" <<'NODE'
const fs = require('fs');
const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (config.inbounds.some(x => x.multiplex?.enabled !== true)) throw new Error('multiplex must remain enabled');
if (config.inbounds.some(x => x.multiplex?.brutal?.enabled !== false)) throw new Error('brutal must follow module detection');
NODE

if [[ -n "${SING_BOX_TEST_BINARY:-}" ]]; then
  "$SING_BOX_TEST_BINARY" check -c "$BRUTAL_DISABLED_CONFIG"
fi

printf 'unsupported|unsupported|/unsupported|3014|\n' >"$NODES_CONFIG"
if unsupported_error="$(validate_nodes_config 2>&1)"; then
  printf 'unsupported protocol unexpectedly accepted\n' >&2
  exit 1
fi
grep -Fq '不支持的节点协议：unsupported' <<<"$unsupported_error"

printf '%s\n' 'GENERATION_SMOKE_OK'
