#!/usr/bin/env bash
set -Eeuo pipefail
export NO_COLOR=1 UI_LANGUAGE=zh
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/argo-singbox.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
node="vless://11111111-1111-4111-8111-111111111111@example.com:443?security=tls&type=ws&host=example.com&path=%2Fnode%3Fed%3D2560#test"
node="${node}$(builtin printf '%0300d' 0)"
check_wrapped() {
  local expected="$1"
  LC_ALL=C awk -v width="$expected" 'length > width {exit 1} NR == 1 && length != width {exit 1}' "$TEST_DIR/wrapped"
  [[ "$(tr -d '\r\n' <"$TEST_DIR/wrapped")" == "$node" ]]
  ! LC_ALL=C grep -q $'\033' "$TEST_DIR/wrapped"
}
if [[ "${1:-}" == --tty ]]; then
  [[ -t 1 ]]
  # Capture rendered chunks while the width detector still sees the real TTY.
  printf() {
    if [[ "$1" == '%s%s%s\n' ]]; then
      builtin printf "$@" >>"$TEST_DIR/wrapped"
    else builtin printf "$@"; fi
  }
  read -r rows columns < <(stty size)
  : >"$TEST_DIR/wrapped"
  print_node_uri "$node"
  expected="$columns"; ((expected <= 128)) || expected=128
  check_wrapped "$expected"
  # Windows ConPTY cannot resize via stty; inject probe results on a real TTY.
  stty() { builtin printf '24 %s\n' "$tty_columns"; }
  for tty_columns in 40 80 128 180 60; do
    : >"$TEST_DIR/wrapped"
    print_node_uri "$node"
    expected="$tty_columns"; ((expected <= 128)) || expected=128
    check_wrapped "$expected"
  done
  # A failed size probe falls back to COLUMNS; invalid values fall back to 128.
  stty() { return 1; }
  COLUMNS=72; : >"$TEST_DIR/wrapped"; print_node_uri "$node"; check_wrapped 72
  COLUMNS=bad; : >"$TEST_DIR/wrapped"; print_node_uri "$node"; check_wrapped 128
  unset -f stty
  builtin printf 'SUBSCRIPTION_TTY_SMOKE_OK\n'
  exit
fi
for mode in default dumb no-color; do
  (case "$mode" in dumb) export TERM=dumb;; no-color) export NO_COLOR=1;; esac
    COLUMNS=40 print_node_uri "$node") >"$TEST_DIR/wrapped"
  check_wrapped 128
done
NODES_FILE="$TEST_DIR/nodes.txt"; NODES_CONFIG="$TEST_DIR/nodes.conf"
for protocol in vless vmess trojan; do
  builtin printf '%s\n' "$node" >>"$NODES_FILE"
  builtin printf '%s|%s|/%s|3011|\n' "$protocol" "$protocol" "$protocol" >>"$NODES_CONFIG"
done
load_env() { :; }; qrencode() { :; }
ARGO_DOMAIN=example.com; UUID=11111111-1111-4111-8111-111111111111
for UI_LANGUAGE in zh en; do
  show_nodes >"$TEST_DIR/page"
  previous=0
  for route in / /raw /auto /base64 /clash /sing-box; do
    line="$(grep -nF "https://${ARGO_DOMAIN}/${UUID}${route}" "$TEST_DIR/page" | head -n1 | cut -d: -f1)"
    ((line > previous)); previous="$line"
  done
  ! LC_ALL=C grep -q $'\033' "$TEST_DIR/page"
  grep -Fq '[03]' "$TEST_DIR/page"
  grep -Fq 'Trojan+WS+TLS' "$TEST_DIR/page"
done
UI_LANGUAGE=zh
grep -Fq "['节点链接格式']='Node links'" "$ROOT_DIR/argo-singbox.sh"
show_install_nodes >"$TEST_DIR/install"
sed '1,/^▸ 原始节点$/d; /^$/d' "$TEST_DIR/install" >"$TEST_DIR/wrapped"
LC_ALL=C awk 'length > 128 {exit 1}' "$TEST_DIR/wrapped"
[[ "$(tr -d '\n' <"$TEST_DIR/wrapped")" == "${node}${node}${node}" ]]
builtin printf 'SUBSCRIPTION_DISPLAY_SMOKE_OK\n'
