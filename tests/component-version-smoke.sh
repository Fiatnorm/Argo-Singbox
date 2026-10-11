#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/argo-singbox.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
FIXTURE="$TEST_DIR/release.json"
try_download() {
  [[ "$1" == "https://api.github.com/repos/${EXPECTED_REPO}/releases/latest" ]]
  cp "$FIXTURE" "$2"
}
for EXPECTED_REPO in SagerNet/sing-box cloudflare/cloudflared; do
  case "$EXPECTED_REPO" in
    SagerNet/sing-box) getter=get_sing_box_version; tag=v1.14.3; expected=1.14.3 ;;
    *) getter=get_cloudflared_version; tag=2026.10.0; expected=2026.10.0 ;;
  esac
  printf '{"tag_name":"%s","prerelease":false,"draft":false}\n' "$tag" >"$FIXTURE"
  [[ "$("$getter")" == "$expected" ]]
  for invalid in \
    '{"tag_name":"v1.15.0-beta.1","prerelease":true,"draft":false}' \
    '{"tag_name":"v1.15.0-beta.1","prerelease":false,"draft":false}' \
    '{"tag_name":"v1.15.0-rc.1","prerelease":false,"draft":false}' \
    '{"tag_name":"v1.15.0","prerelease":true,"draft":false}' \
    '{"tag_name":"v1.15.0","prerelease":false,"draft":true}' \
    '{"tag_name":"v1.15.0"}' \
    '{"message":"API rate limit exceeded"}' \
    'not json'; do
    printf '%s\n' "$invalid" >"$FIXTURE"
    if ("$getter") >"$TEST_DIR/out" 2>"$TEST_DIR/err"; then
      printf 'Accepted invalid release: %s\n' "$invalid" >&2; exit 1
    fi
    [[ ! -s "$TEST_DIR/out" ]]
  done
done
try_download() { return 1; }
if (get_sing_box_version) >"$TEST_DIR/out" 2>"$TEST_DIR/err"; then exit 1; fi
[[ ! -s "$TEST_DIR/out" ]]
printf 'COMPONENT_VERSION_SMOKE_OK\n'
