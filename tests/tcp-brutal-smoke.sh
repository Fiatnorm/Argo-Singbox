#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../ags.sh
source "${ROOT_DIR}/ags.sh"

TEST_SYSTEM="Linux"
TEST_KERNEL="6.8.0-test"
TEST_CONTAINER=0
TEST_MODULES_DIR=1
TEST_MODULES_ENABLED=1

tcp_brutal_system_name() { printf '%s\n' "$TEST_SYSTEM"; }
tcp_brutal_kernel_release() { printf '%s\n' "$TEST_KERNEL"; }
tcp_brutal_container_detected() { [[ "$TEST_CONTAINER" == "1" ]]; }
tcp_brutal_modules_directory_exists() { [[ "$TEST_MODULES_DIR" == "1" ]]; }
tcp_brutal_kernel_modules_enabled() { [[ "$TEST_MODULES_ENABLED" == "1" ]]; }

assert_supported() {
  tcp_brutal_preflight || {
    printf 'expected supported kernel %s: %s\n' "$TEST_KERNEL" "$TCP_BRUTAL_SUPPORT_ERROR" >&2
    exit 1
  }
}

assert_rejected() {
  local expected="$1"
  if tcp_brutal_preflight; then
    printf 'expected rejected kernel/environment: %s\n' "$TEST_KERNEL" >&2
    exit 1
  fi
  [[ "$TCP_BRUTAL_SUPPORT_ERROR" == *"$expected"* ]] || {
    printf 'unexpected rejection: %s\n' "$TCP_BRUTAL_SUPPORT_ERROR" >&2
    exit 1
  }
}

assert_supported
[[ -z "$TCP_BRUTAL_SUPPORT_WARNING" ]]

TEST_KERNEL="5.7.19-test"
assert_supported
[[ "$TCP_BRUTAL_SUPPORT_WARNING" == *"仅支持 IPv4"* ]]

TEST_KERNEL="4.9.0-test"
assert_supported
[[ "$TCP_BRUTAL_SUPPORT_WARNING" == *"fq pacing"* ]]

TEST_KERNEL="4.8.17-test"
assert_rejected "最低要求 4.9"

TEST_KERNEL="5.15.0-microsoft-standard-WSL2"
assert_rejected "不支持加载"

TEST_KERNEL="6.8.0-test"
TEST_CONTAINER=1
assert_rejected "容器"
TEST_CONTAINER=0

TEST_MODULES_DIR=0
assert_rejected "/lib/modules"
TEST_MODULES_DIR=1

TEST_MODULES_ENABLED=0
assert_rejected "CONFIG_MODULES"

TEST_MODULES_ENABLED=1
TEST_KERNEL="4.8.17-test"
DOWNLOAD_CALLED=0
brand() { :; }
subsection() { :; }
key_value() { :; }
red() { :; }
menu_hint() { :; }
download() { DOWNLOAD_CALLED=1; return 1; }
install_tcp_brutal_module
[[ "$DOWNLOAD_CALLED" == "0" ]]

[[ "$TCP_BRUTAL_INSTALLER_REV" == "f11e52d88c7ad2285896de018c2d96d4687f0ab6" ]]
[[ "$TCP_BRUTAL_INSTALLER_SHA256" == "cd7615dd64836d8b239124cad776ac9e5a330830147e1a6892cb69e1ae6c9de6" ]]
[[ "$TCP_BRUTAL_VERSION" == "1.0.3" ]]
[[ "$TCP_BRUTAL_DKMS_SHA256" == "38526721f2e8a8c1907eb289d80526fc2bee9ca09b1f89d91362cea8ef1aad04" ]]

printf '%s\n' 'TCP_BRUTAL_SMOKE_OK'
