#!/usr/bin/env bash
set -Eeuo pipefail
export UI_LANGUAGE=zh
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/argo-singbox.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
NODES_FILE="$TEST_DIR/nodes.txt"; NODES_CONFIG="$TEST_DIR/nodes.conf"
suffix="$(builtin printf '%0300d' 0)"
for protocol in vless vmess trojan; do
  builtin printf '%s://%s\n' "$protocol" "$suffix" >>"$NODES_FILE"
  builtin printf '%s|%s|/%s|3011|\n' "$protocol" "$protocol" "$protocol" >>"$NODES_CONFIG"
done
load_env() { :; }; qrencode() { printf 'QR:%s\n' "${@: -1}"; }
ARGO_DOMAIN=example.com; UUID=11111111-1111-4111-8111-111111111111
# Any attempted terminal-width probe is a failure: output must ignore COLUMNS.
stty() { builtin printf 'Unexpected terminal probe\n' >&2; return 1; }
for UI_LANGUAGE in zh en; do
  for mode in default dumb no-color; do
    (case "$mode" in dumb) export TERM=dumb;; no-color) export NO_COLOR=1;; esac
      COLUMNS=40 show_nodes) >"$TEST_DIR/page"
    previous=0
    for route in / /raw /auto /base64 /clash /sing-box; do
      line="$(grep -nF "https://${ARGO_DOMAIN}/${UUID}${route}" "$TEST_DIR/page" | head -n1 | cut -d: -f1)"
      ((line > previous)); previous="$line"
    done
    grep -E '^(vless|vmess|trojan)://' "$TEST_DIR/page" >"$TEST_DIR/uris"
    cmp "$NODES_FILE" "$TEST_DIR/uris"
    [[ "$(wc -l <"$TEST_DIR/uris")" -eq 3 ]]
    LC_ALL=C awk 'length <= 128 {exit 1}' "$TEST_DIR/uris"
    ! LC_ALL=C grep -q $'\033' "$TEST_DIR/page"
    grep -Fq '[03]' "$TEST_DIR/page"
    grep -Fq 'Trojan+WS+TLS' "$TEST_DIR/page"
    [[ "$(tail -n1 "$TEST_DIR/page")" == trojan://* ]]
  done
done
UI_LANGUAGE=zh
! declare -F node_output_width print_node_uri >/dev/null
{ key_value '管理命令' 'ags / AGS'; show_install_nodes; } >"$TEST_DIR/install"
awk '/ags \/ AGS$/ {getline; if ($0 != "") exit 1; getline; if ($0 != "▸ 订阅链接") exit 1; found=1} END {if (!found) exit 1}' "$TEST_DIR/install"
grep -E '^(vless|vmess|trojan)://' "$TEST_DIR/install" >"$TEST_DIR/uris"
cmp "$NODES_FILE" "$TEST_DIR/uris"
[[ "$(tail -n1 "$TEST_DIR/install")" == trojan://* ]]
show_nodes >"$TEST_DIR/page"
awk 'found {print} /^▸ 订阅链接$/ {found=1}' "$TEST_DIR/page" >"$TEST_DIR/page-content"
awk 'found {print} /^▸ 订阅链接$/ {found=1}' "$TEST_DIR/install" >"$TEST_DIR/install-content"
cmp "$TEST_DIR/page-content" "$TEST_DIR/install-content"
grep -Fq "QR:https://${ARGO_DOMAIN}/${UUID}/auto" "$TEST_DIR/install"
grep -Fq '[03]' "$TEST_DIR/install"
printf 'SUBSCRIPTION_DISPLAY_SMOKE_OK\n'
