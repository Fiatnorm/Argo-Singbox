#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../argo-singbox.sh
source "${ROOT_DIR}/argo-singbox.sh"
PUBLIC_IPS_DETECTED=1
PUBLIC_IPV4=192.0.2.1
PUBLIC_IPV6=2001:db8::1

TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT

WORK_DIR="${TEST_DIR}/work"
CONFIG_DIR="${WORK_DIR}/config"
DATA_DIR="${WORK_DIR}/data"
SUBSCRIPTION_DIR="${WORK_DIR}/subscriptions"
ENV_FILE="${CONFIG_DIR}/argo-singbox.env"
SING_BOX_CONFIG="${CONFIG_DIR}/sing-box.json"
NGINX_CONFIG="${TEST_DIR}/argo-singbox.conf"
NODES_FILE="${DATA_DIR}/nodes.txt"
NODES_CONFIG="${CONFIG_DIR}/nodes.conf"
SUB_FILE="${SUBSCRIPTION_DIR}/subscription.txt"
SUB_BASE64_FILE="${SUBSCRIPTION_DIR}/subscription.base64"
SUB_CLASH_FILE="${SUBSCRIPTION_DIR}/subscription.clash.yaml"
SUB_SING_BOX_FILE="${SUBSCRIPTION_DIR}/subscription.sing-box.json"
SUB_AUTO_QR_FILE="${SUBSCRIPTION_DIR}/subscription.auto.svg"
RULE_SET_DIR="${DATA_DIR}/rule-set"
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
MULTIPLEX_ENABLED=1
TCP_BRUTAL_ENABLED=1

ensure_project_layout() {
  mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$SUBSCRIPTION_DIR" "$RULE_SET_DIR"
}
sing_box_check() {
  if command -v node >/dev/null 2>&1; then
    node -e 'const f=require("fs");JSON.parse(f.readFileSync(process.argv[1],"utf8"))' "$2"
  else
    jq empty "$2"
  fi
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

if command -v node >/dev/null 2>&1; then
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
else
  jq -e '
    (.inbounds | length == 3) and
    ([.inbounds[].type] == ["vless", "vmess", "trojan"]) and
    (all(.inbounds[]; .transport.type == "ws")) and
    (all(.inbounds[]; .multiplex.enabled == true and .multiplex.padding == true)) and
    (all(.inbounds[]; .multiplex.brutal.enabled == true and .multiplex.brutal.up_mbps == 800 and .multiplex.brutal.down_mbps == 1200)) and
    (.experimental.clash_api.external_controller == "127.0.0.1:18085") and
    ([.experimental | keys[]] == ["clash_api"])
  ' "$SING_BOX_CONFIG" >/dev/null
fi

[[ "$(wc -l <"$NODES_FILE")" -eq 3 ]]
grep -Fq 'ed%3D2560' "$NODES_FILE"
! grep -Eq 'packetEncoding=xudp|"packetEncoding":"xudp"|fp=chrome|"fp":"chrome"|aes-128-gcm' "$NODES_FILE"
[[ "$(grep -c '^  - {name:' "$SUB_CLASH_FILE")" -eq 3 ]]
grep -Fq 'cipher: auto' "$SUB_CLASH_FILE"
! grep -Eq 'packet-encoding: xudp|client-fingerprint: chrome|aes-128-gcm' "$SUB_CLASH_FILE"
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
if command -v node >/dev/null 2>&1; then
node - "$SUB_SING_BOX_FILE" <<'NODE'
const fs = require('fs');
const sub = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (sub.outbounds.length !== 3) throw new Error('expected 3 subscription outbounds');
if (sub.outbounds.some(x => !['vless','vmess','trojan'].includes(x.type))) throw new Error('unexpected subscription protocol');
if (sub.outbounds.some(x => x.packet_encoding || x.tls?.utls)) throw new Error('client-specific packet encoding or fingerprint should use defaults');
if (sub.outbounds.find(x => x.type === 'vmess')?.security !== 'auto') throw new Error('VMess security should match SBA auto/default behavior');
if (sub.outbounds.some(x => x.multiplex?.protocol !== 'h2mux' || x.multiplex?.max_streams !== 16 || x.multiplex?.padding !== true)) throw new Error('subscription multiplex missing');
if (sub.outbounds.some(x => x.multiplex?.brutal?.enabled !== true || x.multiplex?.brutal?.up_mbps !== 800 || x.multiplex?.brutal?.down_mbps !== 1200)) throw new Error('subscription brutal missing');
NODE
else
  jq -e '
    (.outbounds | length == 3) and
    (all(.outbounds[]; .type == "vless" or .type == "vmess" or .type == "trojan")) and
    (all(.outbounds[]; (has("packet_encoding") | not) and (.tls? | has("utls") | not))) and
    ((.outbounds[] | select(.type == "vmess") | .security) == "auto") and
    (all(.outbounds[]; .multiplex.protocol == "h2mux" and .multiplex.max_streams == 16 and .multiplex.padding == true)) and
    (all(.outbounds[]; .multiplex.brutal.enabled == true and .multiplex.brutal.up_mbps == 800 and .multiplex.brutal.down_mbps == 1200))
  ' "$SUB_SING_BOX_FILE" >/dev/null
fi

nginx() { :; }
write_nginx_config
grep -Fq "~*(clash|mihomo|stash|clash-verge|clashx|flclash|nyanpasu|surfboard) ${SUB_CLASH_FILE};" "$NGINX_CONFIG"
grep -Fq "~*(sing-box|singbox|sfi|sfa|sfm) ${SUB_SING_BOX_FILE};" "$NGINX_CONFIG"
! grep -Eq 'clash-full|sing-box-full|clash-provider' "$NGINX_CONFIG"
! grep -Fq 'location = /ags-sub' "$NGINX_CONFIG"

BRUTAL_DISABLED_CONFIG="${CONFIG_DIR}/sing-box-brutal-disabled.json"
detect_tcp_brutal() { IS_BRUTAL=false; }
write_sing_box_config "$BRUTAL_DISABLED_CONFIG" "${BIN_DIR}/sing-box"
if command -v node >/dev/null 2>&1; then
node - "$BRUTAL_DISABLED_CONFIG" <<'NODE'
const fs = require('fs');
const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (config.inbounds.some(x => x.multiplex?.enabled !== true)) throw new Error('multiplex must remain enabled');
if (config.inbounds.some(x => x.multiplex?.brutal?.enabled !== false)) throw new Error('brutal must follow module detection');
NODE
else
  jq -e 'all(.inbounds[]; .multiplex.enabled == true and .multiplex.brutal.enabled == false)' "$BRUTAL_DISABLED_CONFIG" >/dev/null
fi

TCP_BRUTAL_ENABLED=0
detect_tcp_brutal() { IS_BRUTAL=true; }
BRUTAL_TOGGLE_CONFIG="${CONFIG_DIR}/sing-box-brutal-toggle-disabled.json"
write_sing_box_config "$BRUTAL_TOGGLE_CONFIG" "${BIN_DIR}/sing-box"
if command -v node >/dev/null 2>&1; then
node - "$BRUTAL_TOGGLE_CONFIG" <<'NODE'
const fs = require('fs');
const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (config.inbounds.some(x => x.multiplex?.enabled !== true || x.multiplex?.padding !== true)) throw new Error('multiplex must remain enabled when only brutal is disabled');
if (config.inbounds.some(x => x.multiplex?.brutal?.enabled !== false)) throw new Error('brutal toggle was not applied');
NODE
else
  jq -e 'all(.inbounds[]; .multiplex.enabled == true and .multiplex.padding == true and .multiplex.brutal.enabled == false)' "$BRUTAL_TOGGLE_CONFIG" >/dev/null
fi

MULTIPLEX_ENABLED=0
generate_nodes
MULTIPLEX_DISABLED_CONFIG="${CONFIG_DIR}/sing-box-multiplex-disabled.json"
write_sing_box_config "$MULTIPLEX_DISABLED_CONFIG" "${BIN_DIR}/sing-box"
if command -v node >/dev/null 2>&1; then
node - "$MULTIPLEX_DISABLED_CONFIG" "$SUB_SING_BOX_FILE" <<'NODE'
const fs = require('fs');
for (const file of process.argv.slice(2)) {
  const config = JSON.parse(fs.readFileSync(file, 'utf8'));
  const entries = config.inbounds || config.outbounds;
  if (entries.some(x => x.multiplex?.enabled !== false)) throw new Error(`multiplex toggle was not applied to ${file}`);
  if (entries.some(x => Object.hasOwn(x.multiplex, 'brutal'))) throw new Error(`disabled multiplex retained brutal in ${file}`);
}
NODE
else
  jq -e 'all(.inbounds[]; .multiplex.enabled == false and (.multiplex | has("brutal") | not))' "$MULTIPLEX_DISABLED_CONFIG" >/dev/null
  jq -e 'all(.outbounds[]; .multiplex.enabled == false and (.multiplex | has("brutal") | not))' "$SUB_SING_BOX_FILE" >/dev/null
fi
[[ "$(grep -o 'smux: {enabled: false}' "$SUB_CLASH_FILE" | wc -l)" -eq 3 ]]

WARP_ENABLED=1
WARP_PROXY_PORT=40000
WARP_DOMAINS=""
WARP_GEOSITES="geosite:google,openai"
ensure_warp_geosite_files() {
  mkdir -p "$RULE_SET_DIR"
  : >"${RULE_SET_DIR}/geosite-google.srs"
  : >"${RULE_SET_DIR}/geosite-openai.srs"
}
WARP_CONFIG="${CONFIG_DIR}/sing-box-warp-geosite.json"
write_sing_box_config "$WARP_CONFIG" "${BIN_DIR}/sing-box"
if command -v node >/dev/null 2>&1; then
node - "$WARP_CONFIG" <<'NODE'
const fs = require('fs');
const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (!config.outbounds.some(x => x.tag === 'warp')) throw new Error('WARP outbound missing');
const warpRule = config.route.rules.find(x => Array.isArray(x.rule_set));
if (!warpRule || warpRule.rule_set.join(',') !== 'geosite-google,geosite-openai' || warpRule.outbound !== 'warp') throw new Error('geosite route missing');
if ((config.route.rule_set || []).map(x => x.tag).join(',') !== 'geosite-google,geosite-openai') throw new Error('local rule-set declarations missing');
if (config.route.rules.some(x => Array.isArray(x.domain_suffix))) throw new Error('empty WARP domain rule should not be emitted');
NODE
else
  jq -e '
    (any(.outbounds[]; .tag == "warp")) and
    (any(.route.rules[]; .rule_set == ["geosite-google", "geosite-openai"] and .outbound == "warp")) and
    ([.route.rule_set[].tag] == ["geosite-google", "geosite-openai"]) and
    (all(.route.rules[]; (.domain_suffix | type) != "array"))
  ' "$WARP_CONFIG" >/dev/null
fi
WARP_ENABLED=0
WARP_GEOSITES=""

if [[ -n "${SING_BOX_TEST_BINARY:-}" ]]; then
  "$SING_BOX_TEST_BINARY" check -c "$BRUTAL_DISABLED_CONFIG"
fi

cat >"$NODES_CONFIG" <<'EOF'
香港 01 🚀|vless|/hk-01|3011|
US "Premium" (02)|vmess|/us-02|3012|
JP/东京+03|trojan|/jp-03|3013|
EOF
WARP_ENABLED=0
MULTIPLEX_ENABLED=1
TCP_BRUTAL_ENABLED=0
validate_nodes_config
generate_nodes
grep -Fq '#%E9%A6%99%E6%B8%AF%2001%20%F0%9F%9A%80' "$NODES_FILE"
grep -Fq 'JP%2F%E4%B8%9C%E4%BA%AC%2B03' "$NODES_FILE"
if command -v node >/dev/null 2>&1; then
node - "$SUB_SING_BOX_FILE" <<'NODE'
const fs = require('fs');
const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const tags = config.outbounds.map(x => x.tag);
const expected = ['香港 01 🚀', 'US "Premium" (02)', 'JP/东京+03'];
if (tags.join('\n') !== expected.join('\n')) throw new Error(`node labels were not preserved: ${JSON.stringify(tags)}`);
NODE
else
  jq -e '[.outbounds[].tag] == ["香港 01 🚀", "US \"Premium\" (02)", "JP/东京+03"]' "$SUB_SING_BOX_FILE" >/dev/null
fi
if command -v python >/dev/null 2>&1 && python -c 'import yaml' >/dev/null 2>&1; then
  python - "$SUB_CLASH_FILE" <<'PY'
import sys
import yaml
with open(sys.argv[1], encoding="utf-8") as stream:
    config = yaml.safe_load(stream)
assert [item["name"] for item in config["proxies"]] == ["香港 01 🚀", 'US "Premium" (02)', "JP/东京+03"]
PY
fi

# Mixed per-node egress preserves WARP priority, SOCKS and all five fields.
cat >"$NODES_CONFIG" <<'EOF'
IPv4|vless|/v4|3011|direct:ipv4
IPv6|vmess|/v6|3012|direct:ipv6
Proxy|trojan|/proxy|3013|proxy.example.com:1080:user:pass
EOF
WARP_ENABLED=1
WARP_DOMAINS=example.org
WARP_GEOSITES=""
write_sing_box_config
generate_nodes
if command -v node >/dev/null 2>&1; then
node - "$SING_BOX_CONFIG" <<'NODE'
const c=JSON.parse(require('fs').readFileSync(process.argv[2],'utf8'));
const out=Object.fromEntries(c.outbounds.map(o=>[o.tag,o]));
if(out.direct.domain_resolver.strategy!=='prefer_ipv4') throw Error('dual stack default');
if(out['direct-IPv4'].domain_resolver.strategy!=='prefer_ipv4') throw Error('IPv4 choice');
if(out['direct-IPv6'].domain_resolver.strategy!=='prefer_ipv6') throw Error('IPv6 choice');
if(out['socks-Proxy'].type!=='socks') throw Error('SOCKS lost');
const routes=c.route.rules.filter(r=>r.action==='route');
if(routes.map(r=>r.outbound).join(',')!=='warp,direct-IPv4,direct-IPv6,socks-Proxy') throw Error('priority');
if(c.inbounds.map(i=>i.type).join(',')!=='vless,vmess,trojan') throw Error('protocols');
NODE
else
  jq -e '.outbounds | any(.tag == "direct-IPv4" and .domain_resolver.strategy == "prefer_ipv4")' "$SING_BOX_CONFIG" >/dev/null
  jq -e '.outbounds | any(.tag == "direct-IPv6" and .domain_resolver.strategy == "prefer_ipv6")' "$SING_BOX_CONFIG" >/dev/null
  jq -e '[.route.rules[] | select(.action == "route") | .outbound] == ["warp","direct-IPv4","direct-IPv6","socks-Proxy"]' "$SING_BOX_CONFIG" >/dev/null
fi
[[ "$(awk -F'|' 'NF!=5 {bad=1} END {print bad+0}' "$NODES_CONFIG")" == 0 ]]
if [[ -n "${AGS_TEST_CORE:-}" ]]; then
  "$AGS_TEST_CORE" check -c "$SING_BOX_CONFIG"
fi
if [[ -n "${AGS_TEST_CONFIG_DIR:-}" ]]; then
  mkdir -p "$AGS_TEST_CONFIG_DIR"
  cp "$SING_BOX_CONFIG" "$AGS_TEST_CONFIG_DIR/server.json"
  cp "$SUB_SING_BOX_FILE" "$AGS_TEST_CONFIG_DIR/client.json"
fi
PUBLIC_IPV4=""
[[ "$(direct_strategy)" == ipv6_only ]]
write_sing_box_config
grep -Fq '"tag":"direct","domain_resolver":{"server":"local","strategy":"ipv6_only"}' "$SING_BOX_CONFIG"
if [[ -n "${AGS_TEST_CORE:-}" ]]; then "$AGS_TEST_CORE" check -c "$SING_BOX_CONFIG"; fi
PUBLIC_IPV4=192.0.2.1
PUBLIC_IPV6=""
[[ "$(direct_strategy)" == ipv4_only ]]
write_sing_box_config
grep -Fq '"tag":"direct","domain_resolver":{"server":"local","strategy":"ipv4_only"}' "$SING_BOX_CONFIG"
if [[ -n "${AGS_TEST_CORE:-}" ]]; then "$AGS_TEST_CORE" check -c "$SING_BOX_CONFIG"; fi
printf 'bad|vless|/bad|3014|direct:ipv7\n' >"$NODES_CONFIG"
if (validate_nodes_config >/dev/null 2>&1); then exit 1; fi
printf 'unsupported|unsupported|/unsupported|3014|\n' >"$NODES_CONFIG"
if unsupported_error="$(validate_nodes_config 2>&1)"; then
  printf 'unsupported protocol unexpectedly accepted\n' >&2
  exit 1
fi
grep -Fq '不支持的节点协议：unsupported' <<<"$unsupported_error"

printf '%s\n' 'GENERATION_SMOKE_OK'
