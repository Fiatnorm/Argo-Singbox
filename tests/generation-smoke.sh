#!/usr/bin/env bash
set -Eeuo pipefail
export UI_LANGUAGE=zh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../argo-singbox.sh
source "${ROOT_DIR}/argo-singbox.sh"

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
OUTBOUND_IP_FAMILY=ipv4

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

cp "$NODES_CONFIG" "${NODES_CONFIG}.valid"
printf 'origin-conflict|vless|/origin-conflict|%s|\n' "$ORIGIN_PORT" >"$NODES_CONFIG"
if origin_conflict_error="$(validate_nodes_config 2>&1)"; then
  printf 'node port matching the Argo origin unexpectedly accepted\n' >&2
  exit 1
fi
grep -Fq "节点端口与 Argo 回源端口冲突：${ORIGIN_PORT}" <<<"$origin_conflict_error"
mv "${NODES_CONFIG}.valid" "$NODES_CONFIG"

WARP_ENABLED=1
WARP_PROXY_PORT=3011
WARP_DOMAINS="openai.com"
if warp_conflict_error="$(validate_environment 2>&1)"; then
  printf 'WARP port matching a node listener unexpectedly accepted\n' >&2
  exit 1
fi
grep -Fq 'WARP 代理端口不能与节点监听端口相同：3011' <<<"$warp_conflict_error"
WARP_PROXY_PORT=3014
[[ "$(next_node_port)" == "3015" ]]
WARP_ENABLED=0
WARP_PROXY_PORT=40000
WARP_DOMAINS=""

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
if (config.outbounds[0]?.inet4_bind_address !== '0.0.0.0' || config.outbounds[0]?.domain_resolver.strategy !== 'ipv4_only') throw new Error('direct outbound IPv4 selection missing');
NODE
else
  jq -e '
    (.inbounds | length == 3) and
    ([.inbounds[].type] == ["vless", "vmess", "trojan"]) and
    (all(.inbounds[]; .transport.type == "ws")) and
    (all(.inbounds[]; .multiplex.enabled == true and .multiplex.padding == true)) and
    (all(.inbounds[]; .multiplex.brutal.enabled == true and .multiplex.brutal.up_mbps == 800 and .multiplex.brutal.down_mbps == 1200)) and
    (.experimental.clash_api.external_controller == "127.0.0.1:18085") and
    (.outbounds[0].inet4_bind_address == "0.0.0.0" and .outbounds[0].domain_resolver.strategy == "ipv4_only") and
    ([.experimental | keys[]] == ["clash_api"])
  ' "$SING_BOX_CONFIG" >/dev/null
fi

OUTBOUND_IP_FAMILY=ipv6
IPV6_CONFIG="${CONFIG_DIR}/sing-box-ipv6-egress.json"
write_sing_box_config "$IPV6_CONFIG" "${BIN_DIR}/sing-box"
if command -v node >/dev/null 2>&1; then
node - "$IPV6_CONFIG" <<'NODE'
const fs = require('fs');
const config = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (config.outbounds[0]?.inet6_bind_address !== '::' || config.outbounds[0]?.domain_resolver.strategy !== 'ipv6_only') throw new Error('direct outbound IPv6 selection missing');
if (Object.hasOwn(config.outbounds[0], 'inet4_bind_address')) throw new Error('IPv6 outbound retained IPv4 bind');
NODE
else
  jq -e '.outbounds[0].inet6_bind_address == "::" and .outbounds[0].domain_resolver.strategy == "ipv6_only" and (.outbounds[0] | has("inet4_bind_address") | not)' "$IPV6_CONFIG" >/dev/null
fi
OUTBOUND_IP_FAMILY=ipv4

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
grep -Fq "<h1>Index of /${UUID}/</h1>" "$NGINX_CONFIG"
grep -Fq "<td class=\"size\">$(stat -c %s "$SUB_FILE")</td>" "$NGINX_CONFIG"
grep -Fq '<a href="auto">auto</a></td><td>—</td><td class="size">—</td>' "$NGINX_CONFIG"
! grep -Eq 'class=hero|class=card|<script|<img' "$NGINX_CONFIG"
if [[ -n "${SUBSCRIPTION_PREVIEW_FILE:-}" ]]; then
  sed -n "s/^[[:space:]]*return 200 '\(.*\)';$/\1/p" "$NGINX_CONFIG" >"$SUBSCRIPTION_PREVIEW_FILE"
  preview_dir="$(dirname "$SUBSCRIPTION_PREVIEW_FILE")"
  install -m 644 "$SUB_FILE" "$preview_dir/raw"
  install -m 644 "$SUB_BASE64_FILE" "$preview_dir/base64"
  install -m 644 "$SUB_BASE64_FILE" "$preview_dir/auto"
  install -m 644 "$SUB_CLASH_FILE" "$preview_dir/clash"
  install -m 644 "$SUB_SING_BOX_FILE" "$preview_dir/sing-box"
fi
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

cat >"$NODES_CONFIG" <<'EOF'
HTTP|vless|/http|3011|http://test:secret@192.0.2.1:6305
SOCKS|vmess|/socks|3012|socks5://test:secret@[2001:db8::1]:6305
Legacy|trojan|/legacy|3013|192.0.2.2:6305:test:secret
Direct6|vless|/direct6|3014|direct:ipv6
EOF
WARP_ENABLED=1 WARP_DOMAINS=example.com WARP_GEOSITES=""
write_sing_box_config
generate_nodes
if [[ -n "${SING_BOX_TEST_BINARY:-}" ]]; then "$SING_BOX_TEST_BINARY" check -c "$SING_BOX_CONFIG"; fi
if command -v node >/dev/null 2>&1; then
node - "$SING_BOX_CONFIG" <<'NODE'
const c = JSON.parse(require('fs').readFileSync(process.argv[2], 'utf8'));
const out = tag => c.outbounds.find(x => x.tag === tag);
if (out('socks-HTTP').type !== 'http' || 'version' in out('socks-HTTP')) throw Error('HTTP outbound fields');
if (out('socks-SOCKS').type !== 'socks' || out('socks-SOCKS').version !== '5') throw Error('SOCKS5 outbound');
if (out('socks-SOCKS').server !== '2001:db8::1') throw Error('IPv6 URL host');
if (out('socks-Legacy').type !== 'socks' || out('direct-Direct6').domain_resolver.strategy !== 'prefer_ipv6') throw Error('legacy egress');
for (const tag of ['HTTP', 'SOCKS', 'Legacy']) {
  const route = c.route.rules.find(x => x.inbound?.includes(tag));
  if (route.outbound !== `socks-${tag}`) throw Error('node proxy route');
  if (c.route.rules.indexOf(route) < c.route.rules.findIndex(x => x.outbound === 'warp')) throw Error('WARP priority');
}
if (c.route.final !== 'direct') throw Error('direct fallback');
NODE
else
  jq -e 'any(.outbounds[]; .tag == "socks-HTTP" and .type == "http" and (has("version") | not)) and any(.outbounds[]; .tag == "socks-SOCKS" and .type == "socks" and .version == "5") and .route.final == "direct"' "$SING_BOX_CONFIG" >/dev/null
fi
for invalid_proxy in 'https://test:secret@192.0.2.1:6305' 'http://test@192.0.2.1:6305' 'http://test:secret@999.0.0.1:6305' 'socks5://test:secret@host:65536' 'http://test:secret@host:6305/path' 'http://test:secret@host:6305|extra' 'http://test:secret@host:6305?query'; do
  if valid_socks5 "$invalid_proxy"; then printf 'invalid proxy accepted\n' >&2; exit 1; fi
done
# CRUD switches the actual stored fifth field to HTTP, preserving other nodes.
require_root() { :; }; validate_environment() { :; }; list_node_profiles() { :; }
begin_config_change() { :; }; apply_runtime_config() { :; }
edit_node_profile >/dev/null <<'EOF'
SOCKS




http://test:secret@192.0.2.3:6306
EOF
grep -Fq 'SOCKS|vmess|/socks|3012|http://test:secret@192.0.2.3:6306' "$NODES_CONFIG"
printf 'unsupported|unsupported|/unsupported|3014|\n' >"$NODES_CONFIG"
if unsupported_error="$(validate_nodes_config 2>&1)"; then
  printf 'unsupported protocol unexpectedly accepted\n' >&2
  exit 1
fi
grep -Fq '不支持的节点协议：unsupported' <<<"$unsupported_error"

printf '%s\n' 'GENERATION_SMOKE_OK'
