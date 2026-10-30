#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/argo-singbox.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
url='https://github.com/example/project/releases/download/v1.0/file'
curl() {
  local candidate="" output=""
  while (($#)); do
    case "$1" in
      https://*) candidate="$1" ;;
      -o) shift; output="$1" ;;
    esac
    shift
  done
  printf '%s\n' "$candidate" >>"$TEST_DIR/requests"
  printf 'partial' >"$output"
  [[ "$candidate" == "https://accel.cloudflare.nyc.mn/$url" ]] || return 22
  printf 'complete' >"$output"
}
try_download "$url" "$TEST_DIR/download"
printf '%s\n' "$url" "https://ghproxy.lvedong.eu.org/$url" \
  "https://accel.cloudflare.nyc.mn/$url" >"$TEST_DIR/expected"
cmp "$TEST_DIR/requests" "$TEST_DIR/expected"
[[ "$(cat "$TEST_DIR/download")" == complete && ! -e "$TEST_DIR/download.part" ]]
printf 'DOWNLOAD_PROXY_SMOKE_OK\n'
