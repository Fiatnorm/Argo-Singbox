#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../argo-singbox.sh
source "${ROOT_DIR}/argo-singbox.sh"

TEST_SYSTEM="Linux"
TEST_KERNEL="6.8.0-test"
TEST_CONTAINER=0
TEST_MODULES_DIR=1
TEST_MODULES_ENABLED=1
TEST_HEADERS_DIR=1
TEST_APT_AVAILABLE=1
TEST_DKMS_INSTALLABLE=1
TEST_HEADERS_INSTALLABLE=1

tcp_brutal_system_name() { printf '%s\n' "$TEST_SYSTEM"; }
tcp_brutal_kernel_release() { printf '%s\n' "$TEST_KERNEL"; }
tcp_brutal_container_detected() { [[ "$TEST_CONTAINER" == "1" ]]; }
tcp_brutal_modules_directory_exists() { [[ "$TEST_MODULES_DIR" == "1" ]]; }
tcp_brutal_kernel_modules_enabled() { [[ "$TEST_MODULES_ENABLED" == "1" ]]; }
tcp_brutal_headers_directory_exists() { [[ "$TEST_HEADERS_DIR" == "1" ]]; }
tcp_brutal_apt_available() { [[ "$TEST_APT_AVAILABLE" == "1" ]]; }
tcp_brutal_dkms_available() { [[ "$TEST_DKMS_INSTALLABLE" == "1" ]]; }
tcp_brutal_debian_system() { return 0; }
tcp_brutal_debian_meta_packages() { printf '%s' 'linux-image-amd64 linux-headers-amd64'; }
tcp_brutal_package_installable() {
  [[ "$1" != "dkms" && "$TEST_HEADERS_INSTALLABLE" == "1" ]]
}

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
TEST_APT_AVAILABLE=0
assert_rejected "APT"
TEST_APT_AVAILABLE=1

TEST_DKMS_INSTALLABLE=0
assert_rejected "dkms"
TEST_DKMS_INSTALLABLE=1

TEST_HEADERS_DIR=0
TEST_HEADERS_INSTALLABLE=1
assert_supported
[[ "$TCP_BRUTAL_HEADERS_STATE" == *"linux-headers-${TEST_KERNEL}"* ]]

TEST_HEADERS_INSTALLABLE=0
assert_rejected "不能使用其他版本头文件替代"
[[ "$TCP_BRUTAL_REMEDIATION" == "debian-kernel-upgrade" ]]

DOWNLOAD_CALLED=0
brand() { :; }
subsection() { :; }
key_value() { :; }
red() { :; }
yellow() { :; }
menu_hint() { :; }
section() { :; }
download() { DOWNLOAD_CALLED=1; return 1; }
READ_RESPONSES=()
READ_INDEX=0
read_input() {
  local response="${READ_RESPONSES[$READ_INDEX]:-}"
  READ_INDEX=$((READ_INDEX + 1))
  printf -v "$2" '%s' "$response"
}

TEST_KERNEL="6.12.43+deb13-amd64"
TEST_HEADERS_DIR=0
TEST_HEADERS_INSTALLABLE=0
install_tcp_brutal_module
[[ "$DOWNLOAD_CALLED" == "0" ]]

APT_CALLS=""
REBOOT_CALLED=0
apt-get() { APT_CALLS+="$*|"; return 0; }
systemctl() { [[ "${1:-}" == "reboot" ]] && REBOOT_CALLED=1; return 0; }
sync() { :; }
info() { :; }
green() { :; }

READ_RESPONSES=(y n)
READ_INDEX=0
guide_tcp_brutal_debian_kernel
[[ "$APT_CALLS" == *"update|"* ]]
[[ "$APT_CALLS" == *"install -y linux-image-amd64 linux-headers-amd64|"* ]]
[[ "$REBOOT_CALLED" == "0" ]]

APT_CALLS=""
REBOOT_CALLED=0
READ_RESPONSES=(y y)
READ_INDEX=0
guide_tcp_brutal_debian_kernel 1
[[ "$APT_CALLS" != *"update|"* ]]
[[ "$APT_CALLS" == *"install -y linux-image-amd64 linux-headers-amd64|"* ]]
[[ "$REBOOT_CALLED" == "1" ]]

# If APT still cannot install the exact running-kernel headers after refresh,
# stop before the official installer and enter the Debian kernel guide.
tcp_brutal_preflight() {
  TCP_BRUTAL_CHECKED_KERNEL="6.12.43+deb13-amd64"
  TCP_BRUTAL_HEADERS_STATE="可安装 · linux-headers-6.12.43+deb13-amd64"
  TCP_BRUTAL_HEADERS_PACKAGE="linux-headers-6.12.43+deb13-amd64"
  TCP_BRUTAL_SUPPORT_ERROR=""
  TCP_BRUTAL_SUPPORT_WARNING=""
  TCP_BRUTAL_REMEDIATION=""
  return 0
}
detect_tcp_brutal() { IS_BRUTAL=false; }
state_value() { :; }
red() { :; }
APT_CALLS=""
REBOOT_CALLED=0
DOWNLOAD_CALLED=0
apt-get() {
  APT_CALLS+="$*|"
  [[ "$*" != *"linux-headers-6.12.43+deb13-amd64"* ]]
}
READ_RESPONSES=(y y n)
READ_INDEX=0
install_tcp_brutal_module
[[ "$APT_CALLS" == *"install -y linux-headers-6.12.43+deb13-amd64|"* ]]
[[ "$APT_CALLS" == *"install -y linux-image-amd64 linux-headers-amd64|"* ]]
[[ "$DOWNLOAD_CALLED" == "0" ]]
[[ "$REBOOT_CALLED" == "0" ]]

TEST_HEADERS_DIR=1
TEST_HEADERS_INSTALLABLE=1
TEST_KERNEL="4.8.17-test"
install_tcp_brutal_module
[[ "$DOWNLOAD_CALLED" == "0" ]]

[[ "$TCP_BRUTAL_INSTALLER_REV" == "f11e52d88c7ad2285896de018c2d96d4687f0ab6" ]]
[[ "$TCP_BRUTAL_INSTALLER_SHA256" == "cd7615dd64836d8b239124cad776ac9e5a330830147e1a6892cb69e1ae6c9de6" ]]
[[ "$TCP_BRUTAL_VERSION" == "1.0.3" ]]
[[ "$TCP_BRUTAL_DKMS_SHA256" == "38526721f2e8a8c1907eb289d80526fc2bee9ca09b1f89d91362cea8ef1aad04" ]]

printf '%s\n' 'TCP_BRUTAL_SMOKE_OK'
