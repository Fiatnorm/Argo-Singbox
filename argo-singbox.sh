#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="2.11.5"
PROJECT_NAME="Argo-Singbox"
COMMAND_NAME="asb"
PROJECT_REPO="Fiatnorm/Argo-Singbox"
PROJECT_BRANCH="main"
WORK_DIR="/etc/asb"
WORK_DIR_NAME="${WORK_DIR##*/}"
LEGACY_WORK_DIR="/etc/sba"
ENV_FILE="${WORK_DIR}/asb.env"
SING_BOX_CONFIG="${WORK_DIR}/sing-box.json"
NGINX_CONFIG="/etc/nginx/conf.d/argo-singbox.conf"
LEGACY_NGINX_CONFIG="/etc/nginx/conf.d/sba.conf"
NODES_FILE="${WORK_DIR}/nodes.txt"
LEGACY_NODES_FILE="/root/argo-singbox_nodes.txt"
LEGACY_SBA_NODES_FILE="/root/sba_nodes.txt"
LOCAL_SCRIPT="${WORK_DIR}/argo-singbox.sh"
BIN_DIR="${WORK_DIR}/bin"
BACKUP_DIR="${WORK_DIR}/backup"
MANAGED_FILE="${WORK_DIR}/managed"
NODES_CONFIG="${WORK_DIR}/nodes.conf"
SUB_FILE="${WORK_DIR}/subscription.txt"
SUB_BASE64_FILE="${WORK_DIR}/subscription.base64"
SUB_CLASH_FILE="${WORK_DIR}/subscription.clash.yaml"
SUB_CLASH_PROVIDER_FILE="${WORK_DIR}/subscription.proxies.yaml"
SUB_SING_BOX_FILE="${WORK_DIR}/subscription.sing-box.json"
SUB_SHADOWROCKET_FILE="${WORK_DIR}/subscription.shadowrocket"
SUB_AUTO_QR_FILE="${WORK_DIR}/subscription.auto.svg"
SING_SERVICE="asb-sing-box"
ARGO_SERVICE="asb-cloudflared"
LEGACY_SING_SERVICE="sba-sing-box"
LEGACY_ARGO_SERVICE="sba-cloudflared"
LEGACY_MIGRATED=0

DEFAULT_SERVER="skk.moe"
DEFAULT_SERVER_PORT="443"
DEFAULT_SING_BOX_VERSION="1.13.0-rc.4"
SING_BOX_FORCE_VERSION_URL="https://raw.githubusercontent.com/fscarmen/sing-box/refs/heads/main/force_version"

DEFAULT_ORIGIN_PORT=3010
ORIGIN_PORT="$DEFAULT_ORIGIN_PORT"

UI_WIDTH=66
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_UNDERLINE=$'\033[4m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_MAGENTA=$'\033[35m'; C_CYAN=$'\033[36m'; C_WHITE=$'\033[37m'
  C_BRIGHT_RED=$'\033[91m'; C_BRIGHT_GREEN=$'\033[92m'; C_BRIGHT_YELLOW=$'\033[93m'
  C_BRIGHT_BLUE=$'\033[94m'; C_BRIGHT_MAGENTA=$'\033[95m'; C_BRIGHT_CYAN=$'\033[96m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_UNDERLINE=""; C_RED=""; C_GREEN=""; C_YELLOW=""
  C_BLUE=""; C_MAGENTA=""; C_CYAN=""; C_WHITE=""; C_BRIGHT_RED=""; C_BRIGHT_GREEN=""
  C_BRIGHT_YELLOW=""; C_BRIGHT_BLUE=""; C_BRIGHT_MAGENTA=""; C_BRIGHT_CYAN=""
fi
ui_line() {
  local char="${1:--}"
  printf '%s%*s%s\n' "$C_BRIGHT_BLUE" "$UI_WIDTH" '' "$C_RESET" | tr ' ' "$char"
}
green() { printf '%s✓ %s%s\n' "$C_BRIGHT_GREEN" "$*" "$C_RESET"; }
yellow() { printf '%s! %s%s\n' "$C_BRIGHT_YELLOW" "$*" "$C_RESET"; }
red() { printf '%s✗ %s%s\n' "$C_BRIGHT_RED" "$*" "$C_RESET" >&2; }
info() { printf '%s• %s%s\n' "$C_BRIGHT_CYAN" "$*" "$C_RESET"; }
display_width() {
  local text="$1" bytes chars
  bytes="$(printf '%s' "$text" | wc -c)"
  chars="$(printf '%s' "$text" | wc -m)"
  printf '%s' "$((chars + (bytes - chars) / 2))"
}
pad_right() {
  local text="$1" target="$2" width pad
  width="$(display_width "$text")"
  pad=$((target - width))
  ((pad < 0)) && pad=0
  printf '%s%*s' "$text" "$pad" ''
}
brand() {
  printf '\n%s%s◆ %s%s\n' "$C_BOLD" "$C_BRIGHT_MAGENTA" "$*" "$C_RESET"
  ui_line
}
system_summary() {
  local os="Linux" arch ip
  if [[ -r /etc/os-release ]]; then
    os="$(
      # shellcheck disable=SC1091
      source /etc/os-release
      printf '%s' "${PRETTY_NAME:-${NAME:-Linux}}"
    )"
  fi
  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) arch="$(uname -m)" ;;
  esac
  ip="$(curl -4fsS --connect-timeout 2 --max-time 3 https://api.ipify.org 2>/dev/null ||
    hostname -I 2>/dev/null | awk '{print $1}')"
  printf '%s · %s · IP %s' "$os" "$arch" "${ip:-未知}"
}
control_panel() {
  printf '\n%s%s' "$C_BOLD" "$C_BRIGHT_BLUE"
  printf '%s\n' '    ___                     _____ _             __'
  printf '%s\n' '   /   |  _________ _____  / ___/(_)___  ____ _/ /_  ____  _  __'
  printf '%s\n' '  / /| | / ___/ __ `/ __ \ \__ \/ / __ \/ __ `/ __ \/ __ \| |/_/'
  printf '%s\n' ' / ___ |/ /  / /_/ / /_/ /___/ / / / / / /_/ / /_/ / /_/ />  <'
  printf '%s\n' '/_/  |_/_/   \__, /\____//____/_/_/ /_/\__, /_.___/\____/_/|_|'
  printf '%s\n' '            /____/                    /____/'
  printf '\n%s%s v%s%s  %sArgo Tunnel · Sing-box Core · WSS Proxy%s\n' \
    "$C_BRIGHT_MAGENTA" "$PROJECT_NAME" "$VERSION" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '%s%-10s%s %s\n' "$C_BRIGHT_CYAN" "系统环境" "$C_RESET" "$(system_summary)"
  ui_line
}
service_status() {
  local service="$1"
  if ! systemctl list-unit-files "${service}.service" --no-legend 2>/dev/null |
    grep -q "^${service}.service"; then
    printf '未安装'
  elif systemctl is-active --quiet "$service"; then
    printf '运行中'
  else
    printf '已停止'
  fi
}
warp_status() {
  if [[ "${WARP_ENABLED:-0}" != "1" ]]; then
    printf '未启用'
  elif systemctl is-active --quiet warp-svc 2>/dev/null &&
    ss -lntH "sport = :${WARP_PROXY_PORT}" 2>/dev/null | grep -q .; then
    printf '运行中 · 127.0.0.1:%s' "$WARP_PROXY_PORT"
  else
    printf '已启用 · 代理异常'
  fi
}
component_versions() {
  printf '脚本 v%s · Sing-box %s · Cloudflared %s' "$VERSION" \
    "$(local_sing_box_version 2>/dev/null || printf '未安装')" \
    "$(local_cloudflared_version 2>/dev/null || printf '未安装')"
}
section() { printf '\n%s%s▸ %s%s\n' "$C_BOLD" "$C_BRIGHT_CYAN" "$*" "$C_RESET"; }
subsection() { section "$*"; }
key_value() {
  printf '%s' "$C_BRIGHT_BLUE"
  pad_right "$1" 14
  printf '%s %s%s%s\n' "$C_RESET" "$C_WHITE" "$2" "$C_RESET"
}
state_value() {
  local color="$C_BRIGHT_YELLOW"
  case "$2" in
    运行中*) color="$C_BRIGHT_GREEN" ;;
    未启用|已停止|未安装) color="$C_BRIGHT_YELLOW" ;;
    *异常*) color="$C_BRIGHT_RED" ;;
  esac
  printf '%s' "$C_BRIGHT_BLUE"
  pad_right "$1" 14
  printf '%s %s%s%s\n' "$C_RESET" "$color" "$2" "$C_RESET"
}
link_value() {
  printf '%s' "$C_BRIGHT_BLUE"
  pad_right "$1" 15
  printf '%s %s%s%s\n' "$C_RESET" "$C_WHITE" "$2" "$C_RESET"
}
prompt() { printf '%s%s› %s%s' "$C_BOLD" "$C_BRIGHT_MAGENTA" "$*" "$C_RESET"; }
read_choice() { prompt "$1"; IFS= read -r REPLY; }
read_input() { prompt "$1"; IFS= read -r "$2"; }
menu_item() {
  printf '  %s%2s%s  %s' "$C_BRIGHT_YELLOW" "$1" "$C_RESET" "$C_WHITE"
  pad_right "$2" 34
  printf '%s%s%s%s\n' "$C_RESET" "$C_BRIGHT_CYAN" "${3:+[$3]}" "$C_RESET"
}
die() { red "$*"; exit 1; }

require_root() {
  local os_id
  [[ ${EUID} -eq 0 ]] || die "请使用 root 用户运行此脚本。"
  command -v systemctl >/dev/null 2>&1 || die "当前系统不支持 systemd。"
  [[ -r /etc/os-release ]] || die "无法识别系统，仅支持 Debian/Ubuntu。"
  os_id="$(
    # shellcheck disable=SC1091
    source /etc/os-release
    printf '%s' "${ID:-}"
  )"
  [[ "$os_id" == "debian" || "$os_id" == "ubuntu" ]] ||
    die "仅支持 Debian/Ubuntu + systemd。"
}

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
  fi
  UUID="${UUID:-}"
  ARGO_DOMAIN="${ARGO_DOMAIN:-}"
  SERVER="${SERVER:-$DEFAULT_SERVER}"
  SERVER_PORT="${SERVER_PORT:-$DEFAULT_SERVER_PORT}"
  ARGO_TOKEN="${ARGO_TOKEN:-}"
  ORIGIN_PORT="${ORIGIN_PORT:-$DEFAULT_ORIGIN_PORT}"
  WARP_ENABLED="${WARP_ENABLED:-0}"
  WARP_PROXY_PORT="${WARP_PROXY_PORT:-40000}"
  WARP_DOMAINS="${WARP_DOMAINS:-}"
}

save_env() {
  local old_umask temp
  old_umask="$(umask)"
  install -d -m 755 "$WORK_DIR"
  umask 077
  temp="$(mktemp "${ENV_FILE}.tmp.XXXXXX")"
  {
    printf 'UUID=%q\n' "$UUID"
    printf 'ARGO_DOMAIN=%q\n' "$ARGO_DOMAIN"
    printf 'SERVER=%q\n' "$SERVER"
    printf 'SERVER_PORT=%q\n' "$SERVER_PORT"
    printf 'ARGO_TOKEN=%q\n' "$ARGO_TOKEN"
    printf 'ORIGIN_PORT=%q\n' "$ORIGIN_PORT"
    printf 'WARP_ENABLED=%q\n' "$WARP_ENABLED"
    printf 'WARP_PROXY_PORT=%q\n' "$WARP_PROXY_PORT"
    printf 'WARP_DOMAINS=%q\n' "$WARP_DOMAINS"
  } >"$temp"
  chmod 600 "$temp"
  mv -f "$temp" "$ENV_FILE"
  umask "$old_umask"
}

valid_uuid() { [[ "${1,,}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; }
valid_path() { [[ "$1" =~ ^/[A-Za-z0-9._~-]+$ ]]; }
valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535)); }
valid_argo_token() { [[ "$1" =~ ^[A-Za-z0-9._~+/=-]+$ ]]; }

normalize_warp_domains() {
  local input="$1" item host output="" seen="," old_ifs="$IFS"
  IFS=','
  for item in $input; do
    item="${item//[[:space:]]/}"
    [[ -n "$item" ]] || continue
    host="${item#*://}"; host="${host%%/*}"; host="${host%%:*}"
    host="${host#.}"
    [[ "$host" =~ ^([A-Za-z0-9-]+\.)*[A-Za-z0-9-]+$ ]] ||
      die "WARP 目标网址无效：${item}"
    host="${host,,}"
    [[ "$seen" == *",${host},"* ]] && continue
    output+="${output:+,}${host}"
    seen+="${host},"
  done
  IFS="$old_ifs"
  [[ -n "$output" ]] || die "至少需要一个 WARP 目标网址。"
  printf '%s\n' "$output"
}

warp_domains_json() {
  local domain first=1 old_ifs="$IFS"
  IFS=','
  for domain in $WARP_DOMAINS; do
    ((first)) || printf ','
    first=0
    printf '"%s"' "$domain"
  done
  IFS="$old_ifs"
}

parse_socks5() {
  local value="$1" host port username password extra
  IFS=':' read -r host port username password extra <<<"$value"
  [[ -n "$host" && -n "$username" && -n "$password" && -z "${extra:-}" ]] ||
    die "SOCKS5 格式必须为 主机:端口:用户名:密码。"
  [[ "$host" =~ ^[A-Za-z0-9.-]+$ ]] || die "SOCKS5 主机格式不正确。"
  valid_port "$port" || die "SOCKS5 端口不正确。"
  [[ "$username" =~ ^[A-Za-z0-9._~-]+$ && "$password" =~ ^[A-Za-z0-9._~-]+$ ]] ||
    die "SOCKS5 用户名和密码仅支持字母、数字及 ._~-。"
  printf '%s|%s|%s|%s\n' "$host" "$port" "$username" "$password"
}

ensure_nodes_config() {
  [[ -f "$NODES_CONFIG" ]] && return
  cat >"$NODES_CONFIG" <<EOF
Argo-Vl|vless|/argo-vl|$((ORIGIN_PORT + 1))|
Argo-Vm|vmess|/argo-vm|$((ORIGIN_PORT + 2))|
Argo-Tr|trojan|/argo-tr|$((ORIGIN_PORT + 3))|
EOF
  chmod 600 "$NODES_CONFIG"
}

next_node_port() {
  local highest="$ORIGIN_PORT" port
  while IFS='|' read -r _ _ _ port _; do
    valid_port "$port" && ((10#$port > 10#$highest)) && highest="$port"
  done <"$NODES_CONFIG"
  ((10#$highest < 65535)) || die "没有可用的后续节点端口。"
  printf '%s\n' "$((10#$highest + 1))"
}

validate_nodes_config() {
  local tag protocol path port socks extra seen_tags="|" seen_paths="|" seen_ports="|"
  [[ -s "$NODES_CONFIG" ]] || die "节点配置为空：${NODES_CONFIG}"
  while IFS='|' read -r tag protocol path port socks extra; do
    [[ -n "$tag" && -z "${extra:-}" ]] || die "节点配置字段数量错误。"
    [[ "$tag" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || die "节点标签格式错误：${tag}"
    [[ "$protocol" =~ ^(vless|vmess|trojan)$ ]] || die "不支持的节点协议：${protocol}"
    valid_path "$path" || die "WS 路径格式错误：${path}"
    valid_port "$port" || die "节点端口错误：${port}"
    [[ "$seen_tags" != *"|${tag}|"* && "$seen_paths" != *"|${path}|"* &&
      "$seen_ports" != *"|${port}|"* ]] || die "节点标签、路径或端口重复。"
    seen_tags+="${tag}|"; seen_paths+="${path}|"; seen_ports+="${port}|"
    [[ -z "$socks" ]] || parse_socks5 "$socks" >/dev/null
  done <"$NODES_CONFIG"
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) die "仅支持 amd64 和 arm64 架构。" ;;
  esac
}

download() {
  local url="$1" output="$2"
  local candidate
  for candidate in "$url" \
    "https://ghproxy.net/${url}" \
    "https://github.moeyy.xyz/${url}"; do
    if curl -fsSL --retry 3 --retry-all-errors --connect-timeout 10 --max-time 180 \
      "$candidate" -o "${output}.part"; then
      [[ -s "${output}.part" ]] || continue
      mv -f "${output}.part" "$output"
      return 0
    fi
    rm -f "${output}.part"
  done
  die "下载失败（已尝试直连和 GitHub 代理）：${url}"
}

fetch_latest_installer() {
  local target="$1" checksum expected attempt
  checksum="$(mktemp)"
  for attempt in {1..3}; do
    download "https://raw.githubusercontent.com/${PROJECT_REPO}/${PROJECT_BRANCH}/argo-singbox.sh.sha256" "$checksum"
    download "https://raw.githubusercontent.com/${PROJECT_REPO}/${PROJECT_BRANCH}/argo-singbox.sh" "$target"
    expected="$(awk '$2 == "argo-singbox.sh" || $2 == "*argo-singbox.sh" {print $1; exit}' "$checksum")"
    if [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] &&
      printf '%s  %s\n' "$expected" "$target" | sha256sum -c - >/dev/null; then
      rm -f "$checksum"
      bash -n "$target" || die "最新安装脚本 Bash 语法检查失败。"
      chmod 755 "$target"
      return 0
    fi
    yellow "安装脚本与校验值暂不一致，正在重新获取（${attempt}/3）。"
  done
  rm -f "$checksum"
  die "最新安装脚本 SHA256 校验失败。"
}

install_dependencies() {
  command -v apt-get >/dev/null 2>&1 || die "轻量版仅支持使用 apt 的 Debian/Ubuntu。"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates nginx openssl tar qrencode
}

install_cloudflare_warp() {
  local answer codename key_file fingerprint
  command -v warp-cli >/dev/null 2>&1 && return
  read_input "未安装官方 Cloudflare WARP 客户端，立即自动安装？[Y/n]: " answer
  [[ ! "$answer" =~ ^[Nn]$ ]] || die "已取消安装 Cloudflare WARP 客户端。"
  command -v apt-get >/dev/null 2>&1 ||
    die "无法自动安装：当前系统没有 apt-get。"
  detect_arch
  codename="${VERSION_CODENAME:-}"
  if [[ -z "$codename" ]] && command -v lsb_release >/dev/null 2>&1; then
    codename="$(lsb_release -cs)"
  fi
  [[ "$codename" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
    die "无法识别 Debian/Ubuntu 发行版代号，不能安全配置 Cloudflare 软件源。"

  info "正在配置 Cloudflare 官方 APT 软件源并安装 cloudflare-warp..."
  DEBIAN_FRONTEND=noninteractive apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates gnupg
  key_file="$(mktemp)"
  if ! curl -fL --retry 3 --retry-all-errors --connect-timeout 10 --max-time 60 \
    https://pkg.cloudflareclient.com/pubkey.gpg -o "$key_file"; then
    rm -f "$key_file"
    die "Cloudflare 软件源签名密钥下载失败。"
  fi
  fingerprint="$(gpg --show-keys --with-colons "$key_file" 2>/dev/null |
    awk -F: '$1 == "fpr" {print $10; exit}')"
  if [[ "$fingerprint" != "C068A2B5771775193CBE1F2F6E2DD2174FA1C3BA" ]]; then
    rm -f "$key_file"
    die "Cloudflare 软件源签名密钥指纹校验失败。"
  fi
  gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg \
    "$key_file"
  rm -f "$key_file"
  printf 'deb [arch=%s signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ %s main\n' \
    "$ARCH" "$codename" >/etc/apt/sources.list.d/cloudflare-client.list
  apt-get update ||
    die "Cloudflare 软件源不可用；请检查系统版本和网络后重试。"
  DEBIAN_FRONTEND=noninteractive apt-get install -y cloudflare-warp ||
    die "cloudflare-warp 安装失败；当前发行版可能不受 Cloudflare 支持。"
  command -v warp-cli >/dev/null 2>&1 ||
    die "cloudflare-warp 已安装，但找不到 warp-cli。"
  green "Cloudflare WARP 客户端安装完成。"
}

ensure_warp_registration() {
  local output answer
  warp-cli --accept-tos registration show >/dev/null 2>&1 && return
  output="$(mktemp)"
  if warp-cli --accept-tos registration new >"$output" 2>&1; then
    rm -f "$output"
    return
  fi
  if grep -qi "Old registration is still around" "$output"; then
    cat "$output" >&2
    rm -f "$output"
    read_input "检测到无法使用的旧 WARP 注册，删除并重新注册？[y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] ||
      die "未清理旧 WARP 注册，已取消启用。"
    warp-cli --accept-tos registration delete >/dev/null 2>&1 ||
      die "旧 WARP 注册删除失败。"
    warp-cli --accept-tos registration new >/dev/null ||
      die "WARP 客户端重新注册失败。"
    return
  fi
  cat "$output" >&2
  rm -f "$output"
  die "WARP 客户端注册失败。"
}

version_gt() {
  [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" == "$1" ]]
}

verify_github_asset() {
  local file="$1" repo="$2" release="$3" asset_name="$4" metadata expected
  metadata="$(mktemp)"
  download "https://api.github.com/repos/${repo}/releases/${release}" "$metadata"
  expected="$(awk -v wanted="$asset_name" '
    /"name":/ {
      line=$0
      sub(/^.*"name":[[:space:]]*"/, "", line)
      sub(/".*$/, "", line)
      matched=(line == wanted)
    }
    matched && /"digest":[[:space:]]*"sha256:/ {
      line=$0
      sub(/^.*"digest":[[:space:]]*"sha256:/, "", line)
      sub(/".*$/, "", line)
      print line
      exit
    }' "$metadata")"
  rm -f "$metadata"
  [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || die "GitHub 未提供 ${asset_name} 的 SHA256，拒绝安装。"
  printf '%s  %s\n' "$expected" "$file" | sha256sum -c - >/dev/null ||
    die "${asset_name} SHA256 校验失败。"
}

get_sing_box_version() {
  local force_version releases version_family result
  force_version="$(curl -fsSL --connect-timeout 3 "$SING_BOX_FORCE_VERSION_URL" 2>/dev/null |
    sed 's/^[vV]//; s/\r//g' || true)"
  if [[ -n "$force_version" ]]; then
    printf '%s\n' "$force_version"
    return
  fi

  releases="$(curl -fsSL --connect-timeout 5 https://api.github.com/repos/SagerNet/sing-box/releases 2>/dev/null || true)"
  version_family="$(sed -n 's/.*"tag_name": *"v\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' <<<"$releases" |
    sort -Vr | head -n1)"
  result="$(sed -n "s/.*\"tag_name\": *\"v\\(${version_family//./\\.}[^\" ]*\\)\".*/\\1/p" <<<"$releases" |
    head -n1)"
  printf '%s\n' "${result:-$DEFAULT_SING_BOX_VERSION}"
}

get_cloudflared_version() {
  local metadata version
  metadata="$(mktemp)"
  download "https://api.github.com/repos/cloudflare/cloudflared/releases/latest" "$metadata"
  version="$(sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' "$metadata" | head -n1)"
  rm -f "$metadata"
  printf '%s\n' "${version#v}"
}

stage_sing_box() {
  local version="${1:-}" target="$2" archive temp_dir
  [[ -n "$version" ]] || version="$(get_sing_box_version)"
  [[ -n "$version" ]] || die "无法确定 sing-box 版本。"
  archive="$(mktemp --suffix=.tar.gz)"
  download "https://github.com/SagerNet/sing-box/releases/download/v${version}/sing-box-${version}-linux-${ARCH}.tar.gz" "$archive"
  verify_github_asset "$archive" "SagerNet/sing-box" "tags/v${version}" \
    "sing-box-${version}-linux-${ARCH}.tar.gz"
  temp_dir="$(mktemp -d)"
  tar -xzf "$archive" -C "$temp_dir"
  install -m 755 "$temp_dir/sing-box-${version}-linux-${ARCH}/sing-box" "$target"
  "$target" version >/dev/null
  rm -rf "$archive" "$temp_dir"
}

stage_cloudflared() {
  local target="$1" suffix
  [[ "$ARCH" == "amd64" ]] && suffix="amd64" || suffix="arm64"
  download "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${suffix}" "$target"
  verify_github_asset "$target" "cloudflare/cloudflared" "latest" "cloudflared-linux-${suffix}"
  chmod 755 "$target"
  "$target" --version >/dev/null
}

local_sing_box_version() {
  "$BIN_DIR/sing-box" version 2>/dev/null | awk '/version/{print $NF; exit}'
}

local_cloudflared_version() {
  "$BIN_DIR/cloudflared" --version 2>/dev/null |
    awk '{for (i=1; i<=NF; i++) if ($i=="version") {print $(i+1); exit}}'
}

write_sing_box_config() {
  local tag protocol path port socks first=1 values host proxy_port username password
  ensure_nodes_config
  validate_nodes_config
  printf '{"log":{"level":"info","timestamp":true},"inbounds":[\n' >"$SING_BOX_CONFIG"
  while IFS='|' read -r tag protocol path port socks; do
    ((first)) || printf ',\n' >>"$SING_BOX_CONFIG"; first=0
    printf '{"type":"%s","tag":"%s","listen":"127.0.0.1","listen_port":%s,' "$protocol" "$tag" "$port" >>"$SING_BOX_CONFIG"
    case "$protocol" in
      trojan) printf '"users":[{"password":"%s"}],' "$UUID" >>"$SING_BOX_CONFIG" ;;
      vmess) printf '"users":[{"uuid":"%s","alterId":0}],' "$UUID" >>"$SING_BOX_CONFIG" ;;
      vless) printf '"users":[{"uuid":"%s","flow":""}],' "$UUID" >>"$SING_BOX_CONFIG" ;;
    esac
    printf '"transport":{"type":"ws","path":"%s","max_early_data":2560,"early_data_header_name":"Sec-WebSocket-Protocol"},' "$path" >>"$SING_BOX_CONFIG"
    printf '"multiplex":{"enabled":true,"padding":true,"brutal":{"enabled":false,"up_mbps":1000,"down_mbps":1000}}}' >>"$SING_BOX_CONFIG"
  done <"$NODES_CONFIG"
  printf '\n],"outbounds":[{"type":"direct","tag":"direct"}' >>"$SING_BOX_CONFIG"
  if [[ "$WARP_ENABLED" == "1" ]]; then
    valid_port "$WARP_PROXY_PORT" || die "WARP 本地代理端口无效。"
    WARP_DOMAINS="$(normalize_warp_domains "$WARP_DOMAINS")"
    printf ',{"type":"socks","tag":"warp","server":"127.0.0.1","server_port":%s,"version":"5"}' \
      "$WARP_PROXY_PORT" >>"$SING_BOX_CONFIG"
  fi
  while IFS='|' read -r tag protocol path port socks; do
    [[ -n "$socks" ]] || continue
    values="$(parse_socks5 "$socks")"; IFS='|' read -r host proxy_port username password <<<"$values"
    printf ',{"type":"socks","tag":"socks-%s","server":"%s","server_port":%s,"version":"5","username":"%s","password":"%s"}' \
      "$tag" "$host" "$proxy_port" "$username" "$password" >>"$SING_BOX_CONFIG"
  done <"$NODES_CONFIG"
  printf '],"route":{"rules":[' >>"$SING_BOX_CONFIG"; first=1
  if [[ "$WARP_ENABLED" == "1" ]]; then
    printf '{"action":"sniff"},{"domain_suffix":[' >>"$SING_BOX_CONFIG"
    warp_domains_json >>"$SING_BOX_CONFIG"
    printf '],"action":"route","outbound":"warp"}' >>"$SING_BOX_CONFIG"
    first=0
  fi
  while IFS='|' read -r tag protocol path port socks; do
    [[ -n "$socks" ]] || continue
    ((first)) || printf ',' >>"$SING_BOX_CONFIG"; first=0
    printf '{"inbound":["%s"],"action":"route","outbound":"socks-%s"}' "$tag" "$tag" >>"$SING_BOX_CONFIG"
  done <"$NODES_CONFIG"
  printf '],"final":"direct"}}\n' >>"$SING_BOX_CONFIG"
  chmod 600 "$SING_BOX_CONFIG"
  "$BIN_DIR/sing-box" check -c "$SING_BOX_CONFIG"
}

write_nginx_config() {
  local tag protocol path port socks
  ensure_nodes_config
  validate_nodes_config
  cat >"$NGINX_CONFIG" <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

map \$http_user_agent \$asb_subscription_file {
    default ${SUB_BASE64_FILE};
    ~*(clash|mihomo|stash) ${SUB_CLASH_FILE};
    ~*(sing-box|singbox|sfi|sfa|sfm) ${SUB_SING_BOX_FILE};
    ~*(shadowrocket) ${SUB_SHADOWROCKET_FILE};
}

server {
    listen 127.0.0.1:${ORIGIN_PORT};
    server_name ${ARGO_DOMAIN};

EOF
  while IFS='|' read -r tag protocol path port socks; do
    cat >>"$NGINX_CONFIG" <<EOF
    location = ${path} {
        if (\$http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:${port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
        proxy_redirect off;
    }
EOF
  done <"$NODES_CONFIG"
  cat >>"$NGINX_CONFIG" <<EOF
    location = /${UUID} {
        return 302 /${UUID}/;
    }
    location = /${UUID}/ {
        default_type text/html;
        return 200 '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Argo-Singbox 订阅面板</title><style>:root{color-scheme:light;--blue:#0969da;--blue2:#1d4ed8;--text:#172033;--muted:#5f6f89;--line:#d8e3f5;--bg:#fff}*{box-sizing:border-box}body{margin:0;background:var(--bg);font:16px/1.6 system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:var(--text)}main{max-width:860px;margin:32px auto;padding:0 18px 40px}h1{margin:0 0 8px;color:var(--blue);font-size:28px;letter-spacing:0}p{margin:0 0 18px;color:var(--muted)}.qr{display:flex;gap:18px;align-items:center;border:1px solid var(--line);border-radius:8px;padding:16px;margin:18px 0 20px}.qr img{width:168px;height:168px;image-rendering:pixelated}.qr a,.item{color:var(--blue);text-decoration:none}.qr a:hover,.item:hover{text-decoration:underline}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:10px}.item{display:block;border:1px solid var(--line);border-radius:8px;padding:12px 14px}.name{display:block;font-weight:700;color:var(--blue2)}.desc{display:block;margin-top:3px;color:var(--muted);font-size:13px}code{color:var(--blue);background:#eef6ff;padding:2px 6px;border-radius:5px}@media (max-width:560px){.qr{display:block}.qr img{width:150px;height:150px;margin-bottom:10px}}</style></head><body><main><h1>Argo-Singbox 订阅面板</h1><p>按客户端选择订阅。终端执行 <code>asb -n</code> 可查看订阅链接、自动适配 QR 和明文节点。</p><section class="qr"><a href="auto"><img src="auto-qr.svg" alt="自动适配订阅 QR"></a><div><span class="name">自动适配订阅 QR</span><span class="desc">扫码导入自动适配订阅；点击二维码打开订阅链接。</span><p><a href="auto">打开自动适配订阅</a></p></div></section><div class="grid"><a class="item" href="auto"><span class="name">自动适配订阅</span><span class="desc">根据客户端 User-Agent 返回合适格式</span></a><a class="item" href="raw"><span class="name">明文节点链接</span><span class="desc">逐行 vless / vmess / trojan 原始链接</span></a><a class="item" href="base64"><span class="name">Base64 通用订阅</span><span class="desc">V2rayN、NekoBox 等通用导入</span></a><a class="item" href="clash"><span class="name">Clash/Mihomo 订阅</span><span class="desc">完整 YAML 配置</span></a><a class="item" href="proxies"><span class="name">Clash Provider 订阅</span><span class="desc">仅代理节点列表</span></a><a class="item" href="sing-box"><span class="name">sing-box 订阅</span><span class="desc">JSON 出站配置</span></a><a class="item" href="shadowrocket"><span class="name">Shadowrocket 订阅</span><span class="desc">兼容 Shadowrocket 的 Base64 订阅</span></a></div></main></body></html>';
    }
    location = /${UUID}/auto-qr.svg {
        default_type image/svg+xml;
        alias ${SUB_AUTO_QR_FILE};
    }
    location = /${UUID}/auto {
        default_type text/plain;
        alias \$asb_subscription_file;
    }
    location = /${UUID}/raw {
        default_type text/plain;
        alias ${SUB_FILE};
    }
    location = /${UUID}/base64 {
        default_type text/plain;
        alias ${SUB_BASE64_FILE};
    }
    location = /${UUID}/clash {
        default_type text/yaml;
        alias ${SUB_CLASH_FILE};
    }
    location = /${UUID}/proxies {
        default_type text/yaml;
        alias ${SUB_CLASH_PROVIDER_FILE};
    }
    location = /${UUID}/sing-box {
        default_type application/json;
        alias ${SUB_SING_BOX_FILE};
    }
    location = /${UUID}/shadowrocket {
        default_type text/plain;
        alias ${SUB_SHADOWROCKET_FILE};
    }
    location = /asb-sub {
        default_type text/plain;
        alias ${SUB_FILE};
    }
    location = /asb-sub-base64 {
        default_type text/plain;
        alias ${SUB_BASE64_FILE};
    }
    location / { return 404; }
}
EOF
  nginx -t
}

write_services() {
  cat >"/etc/systemd/system/${SING_SERVICE}.service" <<EOF
[Unit]
Description=Argo-Singbox sing-box
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${WORK_DIR}
ExecStart=${BIN_DIR}/sing-box run -c ${SING_BOX_CONFIG}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
  chmod 600 "/etc/systemd/system/${SING_SERVICE}.service"

  cat >"/etc/systemd/system/${ARGO_SERVICE}.service" <<EOF
[Unit]
Description=Argo-Singbox Cloudflare 固定隧道
After=network-online.target nginx.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=${BIN_DIR}/cloudflared tunnel --edge-ip-version auto --no-autoupdate run --token ${ARGO_TOKEN}
Restart=on-failure
RestartSec=5
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
  chmod 600 "/etc/systemd/system/${ARGO_SERVICE}.service"
}

generate_nodes() {
  local old_umask vmess_json vmess_link tag protocol path port socks encoded_path first uri_server auto_url
  ensure_nodes_config
  validate_nodes_config
  old_umask="$(umask)"
  umask 077
  uri_server="$SERVER"
  [[ "$uri_server" == *:* ]] && uri_server="[${uri_server}]"
  : >"$NODES_FILE"
  while IFS='|' read -r tag protocol path port socks; do
    encoded_path="%2F${path#/}%3Fed%3D2560"
    case "$protocol" in
      vless) printf 'vless://%s@%s:%s?encryption=none&security=tls&sni=%s&insecure=0&allowInsecure=0&type=ws&host=%s&path=%s#%s\n' \
        "$UUID" "$uri_server" "$SERVER_PORT" "$ARGO_DOMAIN" "$ARGO_DOMAIN" "$encoded_path" "$tag" >>"$NODES_FILE" ;;
      trojan) printf 'trojan://%s@%s:%s?security=tls&sni=%s&insecure=0&allowInsecure=0&type=ws&host=%s&path=%s#%s\n' \
        "$UUID" "$uri_server" "$SERVER_PORT" "$ARGO_DOMAIN" "$ARGO_DOMAIN" "$encoded_path" "$tag" >>"$NODES_FILE" ;;
      vmess)
        vmess_json="{\"v\":\"2\",\"ps\":\"${tag}\",\"add\":\"${SERVER}\",\"port\":\"${SERVER_PORT}\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${ARGO_DOMAIN}\",\"path\":\"${path}?ed=2560\",\"tls\":\"tls\",\"sni\":\"${ARGO_DOMAIN}\",\"alpn\":\"\"}"
        vmess_link="$(printf '%s' "$vmess_json" | base64 -w 0)"
        printf 'vmess://%s\n' "$vmess_link" >>"$NODES_FILE" ;;
    esac
  done <"$NODES_CONFIG"
  chmod 600 "$NODES_FILE"
  install -m 644 "$NODES_FILE" "$SUB_FILE"
  base64 -w 0 "$NODES_FILE" >"$SUB_BASE64_FILE"
  cp -f "$SUB_BASE64_FILE" "$SUB_SHADOWROCKET_FILE"
  auto_url="https://${ARGO_DOMAIN}/${UUID}/auto"
  qrencode -t SVG -o "$SUB_AUTO_QR_FILE" "$auto_url"
  printf 'proxies:\n' >"$SUB_CLASH_PROVIDER_FILE"
  while IFS='|' read -r tag protocol path port socks; do
    case "$protocol" in
      vless) printf '  - {name: "%s", type: vless, server: "%s", port: %s, uuid: %s, encryption: none, udp: true, tls: true, servername: %s, skip-cert-verify: false, network: ws, ws-opts: {path: "%s", headers: {Host: %s}, max-early-data: 2560, early-data-header-name: Sec-WebSocket-Protocol}}\n' \
        "$tag" "$SERVER" "$SERVER_PORT" "$UUID" "$ARGO_DOMAIN" "$path" "$ARGO_DOMAIN" ;;
      vmess) printf '  - {name: "%s", type: vmess, server: "%s", port: %s, uuid: %s, alterId: 0, cipher: auto, udp: true, tls: true, servername: %s, skip-cert-verify: false, network: ws, ws-opts: {path: "%s", headers: {Host: %s}, max-early-data: 2560, early-data-header-name: Sec-WebSocket-Protocol}}\n' \
        "$tag" "$SERVER" "$SERVER_PORT" "$UUID" "$ARGO_DOMAIN" "$path" "$ARGO_DOMAIN" ;;
      trojan) printf '  - {name: "%s", type: trojan, server: "%s", port: %s, password: %s, udp: true, tls: true, sni: %s, skip-cert-verify: false, network: ws, ws-opts: {path: "%s", headers: {Host: %s}, max-early-data: 2560, early-data-header-name: Sec-WebSocket-Protocol}}\n' \
        "$tag" "$SERVER" "$SERVER_PORT" "$UUID" "$ARGO_DOMAIN" "$path" "$ARGO_DOMAIN" ;;
    esac
  done <"$NODES_CONFIG" >>"$SUB_CLASH_PROVIDER_FILE"
  cat "$SUB_CLASH_PROVIDER_FILE" >"$SUB_CLASH_FILE"
  printf 'proxy-groups:\n  - name: PROXY\n    type: select\n    proxies:\n' >>"$SUB_CLASH_FILE"
  while IFS='|' read -r tag protocol path port socks; do
    printf '      - "%s"\n' "$tag"
  done <"$NODES_CONFIG" >>"$SUB_CLASH_FILE"
  printf 'rules:\n  - MATCH,PROXY\n' >>"$SUB_CLASH_FILE"

  printf '{"outbounds":[' >"$SUB_SING_BOX_FILE"
  first=1
  while IFS='|' read -r tag protocol path port socks; do
    ((first)) || printf ',' >>"$SUB_SING_BOX_FILE"; first=0
    printf '{"type":"%s","tag":"%s","server":"%s","server_port":%s,' \
      "$protocol" "$tag" "$SERVER" "$SERVER_PORT" >>"$SUB_SING_BOX_FILE"
    case "$protocol" in
      trojan) printf '"password":"%s",' "$UUID" >>"$SUB_SING_BOX_FILE" ;;
      vmess) printf '"uuid":"%s","security":"auto","alter_id":0,' "$UUID" >>"$SUB_SING_BOX_FILE" ;;
      vless) printf '"uuid":"%s","flow":"","packet_encoding":"xudp",' "$UUID" >>"$SUB_SING_BOX_FILE" ;;
    esac
    printf '"tls":{"enabled":true,"server_name":"%s","insecure":false,"utls":{"enabled":true,"fingerprint":"chrome"}},"transport":{"type":"ws","path":"%s","headers":{"Host":"%s"},"max_early_data":2560,"early_data_header_name":"Sec-WebSocket-Protocol"}}' \
      "$ARGO_DOMAIN" "$path" "$ARGO_DOMAIN" >>"$SUB_SING_BOX_FILE"
  done <"$NODES_CONFIG"
  printf ']}\n' >>"$SUB_SING_BOX_FILE"
  chmod 644 "$SUB_BASE64_FILE"
  chmod 644 "$SUB_CLASH_FILE" "$SUB_CLASH_PROVIDER_FILE" "$SUB_SING_BOX_FILE" \
    "$SUB_SHADOWROCKET_FILE" "$SUB_AUTO_QR_FILE"
  umask "$old_umask"
}

create_local_command() {
  local source_script="${1:-$0}"
  install -m 755 "$source_script" "${LOCAL_SCRIPT}.new"
  mv -f "${LOCAL_SCRIPT}.new" "$LOCAL_SCRIPT"
  ln -sfn "$LOCAL_SCRIPT" "/usr/local/bin/${COMMAND_NAME}"
  rm -f /usr/local/bin/sb /usr/local/bin/argo-singbox
}

sync_argo_domain() {
  local actual_domain attempt active_since
  active_since="$(systemctl show "$ARGO_SERVICE" -p ActiveEnterTimestamp --value 2>/dev/null || true)"
  for attempt in {1..10}; do
    if [[ -n "$active_since" ]]; then
      actual_domain="$(journalctl -u "$ARGO_SERVICE" --since "$active_since" --no-pager -o cat 2>/dev/null |
        sed -n 's/.*"hostname"[^A-Za-z0-9.-]*\([A-Za-z0-9.-]\+\).*/\1/p' | tail -n1)"
    else
      actual_domain="$(journalctl -u "$ARGO_SERVICE" -n 200 --no-pager -o cat 2>/dev/null |
        sed -n 's/.*"hostname"[^A-Za-z0-9.-]*\([A-Za-z0-9.-]\+\).*/\1/p' | tail -n1)"
    fi
    [[ -n "$actual_domain" ]] && break
    sleep 1
  done
  if [[ -n "$actual_domain" && "$actual_domain" != "$ARGO_DOMAIN" ]]; then
    yellow "检测到 Token 实际域名为 ${actual_domain}，已替换输入域名 ${ARGO_DOMAIN}。"
    ARGO_DOMAIN="$actual_domain"
    save_env
    write_nginx_config
    systemctl reload nginx
  elif [[ -z "$actual_domain" ]]; then
    # 固定 Token 隧道的日志并不保证输出 Public Hostname；保留用户输入值即可。
    :
  fi
}

wait_for_services() {
  local attempt service ready
  for attempt in {1..20}; do
    ready=1
    for service in nginx "$SING_SERVICE" "$ARGO_SERVICE"; do
      systemctl is-active --quiet "$service" || ready=0
    done
    [[ "$ready" -eq 1 ]] && return 0
    sleep 1
  done
  return 1
}

health_check() {
  local failed=0 public_code public_headers curl_status port path tag protocol socks
  ensure_nodes_config
  section "运行检查"
  for service in nginx "$SING_SERVICE" "$ARGO_SERVICE"; do
    if systemctl is-active --quiet "$service"; then
      green "${service}：运行正常"
    else
      red "${service}：运行失败"
      systemctl --no-pager --full status "$service" || true
      journalctl -u "$service" -n 20 --no-pager -o cat 2>/dev/null || true
      failed=1
    fi
  done

  while read -r port; do
    if ! ss -lntH "sport = :${port}" 2>/dev/null | grep -q .; then
      red "本地端口 ${port} 未监听。"
      failed=1
    fi
  done < <(printf '%s\n' "$ORIGIN_PORT"; cut -d'|' -f4 "$NODES_CONFIG")

  while IFS='|' read -r tag protocol path port socks; do
    curl_status=0
    public_headers="$(curl -ksS --http1.1 --connect-timeout 5 --max-time 8 -D - -o /dev/null \
      --connect-to "${ARGO_DOMAIN}:${SERVER_PORT}:${SERVER}:${SERVER_PORT}" \
      -H "Connection: Upgrade" -H "Upgrade: websocket" \
      -H "Sec-WebSocket-Version: 13" \
      -H "Sec-WebSocket-Key: SGVsbG9Xb3JsZDEyMzQ1Ng==" \
      "https://${ARGO_DOMAIN}:${SERVER_PORT}${path}" 2>/dev/null)" || curl_status=$?
    public_code="$(awk '/^HTTP/{code=$2} END{print code}' <<<"$public_headers")"
    if grep -qi '^cf-mitigated: *challenge' <<<"$public_headers"; then
      red "${path}：Cloudflare 人机挑战（HTTP ${public_code:-403}）"
      failed=1
    elif [[ "$public_code" == "101" ]]; then
      green "${path}：公网 WebSocket 握手正常"
    elif [[ "$curl_status" -eq 28 ]]; then
      yellow "${path}：公网握手探测超时，未作为安装失败（请用客户端实测）"
    else
      red "${path}：公网 WebSocket 握手失败（HTTP ${public_code:-000}）"
      failed=1
    fi
  done <"$NODES_CONFIG"
  [[ "$failed" -eq 0 ]] || yellow "请确认 Public Hostname 指向 http://localhost:${ORIGIN_PORT}，并跳过全部代理路径的 Challenge/WAF。"

  return "$failed"
}

prompt_install_values() {
  local value endpoint
  read_input "请输入 Argo Token（必填）: " value
  valid_argo_token "$value" || die "Argo Token 格式不正确。"
  ARGO_TOKEN="$value"
  read_input "请输入 Argo 域名（必填）${ARGO_DOMAIN:+ [${ARGO_DOMAIN}]}: " value
  ARGO_DOMAIN="${value:-$ARGO_DOMAIN}"
  [[ -n "$ARGO_DOMAIN" ]] || die "Argo 域名不能为空。"
  [[ -n "$UUID" ]] || UUID="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || true)"
  [[ -n "$UUID" ]] || UUID="$(openssl rand -hex 16 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\)$/\1-\2-\3-\4-\5/')"
  read_input "请输入 UUID [${UUID}]: " value
  UUID="${value:-$UUID}"
  [[ "${UUID,,}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]] ||
    die "UUID 格式不正确。"
  read_input "请输入 Cloudflare 优选入口 域名/IP:端口 [${SERVER}:${SERVER_PORT}]: " endpoint
  endpoint="${endpoint:-${SERVER}:${SERVER_PORT}}"
  parse_endpoint "$endpoint"
  [[ "$ARGO_DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || die "Argo 域名格式不正确。"
}

parse_endpoint() {
  local endpoint="$1" host port
  if [[ "$endpoint" =~ ^\[([0-9A-Fa-f:]+)\]:([0-9]+)$ ]]; then
    host="${BASH_REMATCH[1]}"; port="${BASH_REMATCH[2]}"
  elif [[ "$endpoint" =~ ^([^:]+):([0-9]+)$ ]]; then
    host="${BASH_REMATCH[1]}"; port="${BASH_REMATCH[2]}"
  else
    die "优选入口格式必须为 域名/IP:端口（IPv6 使用 [地址]:端口）。"
  fi
  [[ "$host" =~ ^[A-Za-z0-9._:-]+$ ]] || die "优选域名或 IP 格式不正确。"
  valid_port "$port" || die "端口必须是 1 到 65535。"
  SERVER="$host"
  SERVER_PORT="$((10#$port))"
}

assert_service_names_available() {
  local unit marker
  for unit in "$SING_SERVICE" "$ARGO_SERVICE"; do
    marker="/etc/systemd/system/${unit}.service"
    if [[ -e "$marker" ]] && ! grep -Eq "^Description=(SBA|Argo-Singbox) " "$marker"; then
      die "检测到非本项目服务 ${unit}.service，安装已停止，未覆盖现有服务。"
    fi
  done
  for unit in sing-box cloudflared; do
    marker="/etc/systemd/system/${unit}.service"
    [[ -e "$marker" ]] || continue
    if grep -Eq "^Description=(SBA|Argo-Singbox) " "$marker"; then
      yellow "检测到本项目旧版 ${unit}.service，将迁移为项目专属服务名。"
      systemctl disable --now "$unit" 2>/dev/null || true
      rm -f "$marker"
    else
      die "检测到现有 ${unit}.service 且不属于本项目。为避免服务冲突，安装已停止。"
    fi
  done
}

is_project_service() {
  local unit_file="$1"
  [[ -f "$unit_file" ]] &&
    grep -Eq '^Description=(SBA|Argo-Singbox) ' "$unit_file"
}

migrate_legacy_install() {
  local migration_backup temp legacy_target
  [[ -d "$LEGACY_WORK_DIR" ]] || return 0
  if [[ -L "$LEGACY_WORK_DIR" ]]; then
    legacy_target="$(readlink -f "$LEGACY_WORK_DIR" 2>/dev/null || true)"
    if [[ "$legacy_target" == "$WORK_DIR" && -f "$MANAGED_FILE" ]]; then
      LEGACY_MIGRATED=1
      return 0
    fi
    die "检测到未知旧目录符号链接 ${LEGACY_WORK_DIR}，拒绝自动迁移。"
  fi
  [[ -f "${LEGACY_WORK_DIR}/managed" ]] ||
    die "检测到 ${LEGACY_WORK_DIR} 但缺少项目所有权标记，拒绝自动迁移。"
  [[ ! -e "$WORK_DIR" ]] ||
    die "${WORK_DIR} 与旧目录 ${LEGACY_WORK_DIR} 同时存在，请先人工核对，拒绝自动覆盖。"
  mv "$LEGACY_WORK_DIR" "$WORK_DIR"
  ln -s "$WORK_DIR" "$LEGACY_WORK_DIR"
  migration_backup="${WORK_DIR}/backup/pre-asb-namespace"
  install -d -m 700 "$migration_backup"
  [[ -f "${WORK_DIR}/sba.env" ]] && cp -a "${WORK_DIR}/sba.env" "$migration_backup/"
  [[ -f "$NODES_CONFIG" ]] && cp -a "$NODES_CONFIG" "$migration_backup/"
  if [[ -f "${WORK_DIR}/sba.env" ]]; then
    mv "${WORK_DIR}/sba.env" "$ENV_FILE"
  fi
  if [[ -f "$NODES_CONFIG" ]]; then
    temp="$(mktemp)"
    sed -e 's#|/sba-vl|#|/argo-vl|#g' \
      -e 's#|/sba-vm|#|/argo-vm|#g' \
      -e 's#|/sba-tr|#|/argo-tr|#g' "$NODES_CONFIG" >"$temp"
    install -m 600 "$temp" "$NODES_CONFIG"
    rm -f "$temp"
  fi
  LEGACY_MIGRATED=1
  green "已将旧安装目录迁移为 ${WORK_DIR}。"
}

remove_legacy_services() {
  local service unit_file
  for service in "$LEGACY_SING_SERVICE" "$LEGACY_ARGO_SERVICE"; do
    unit_file="/etc/systemd/system/${service}.service"
    [[ -e "$unit_file" ]] || continue
    if is_project_service "$unit_file"; then
      systemctl disable --now "$service" 2>/dev/null || true
      rm -f "$unit_file"
    else
      yellow "保留非本项目旧服务：${service}.service"
    fi
  done
}

remove_legacy_symlink() {
  local target
  [[ -L "$LEGACY_WORK_DIR" ]] || return 0
  target="$(readlink -f "$LEGACY_WORK_DIR" 2>/dev/null || true)"
  [[ "$target" == "$WORK_DIR" ]] && rm -f "$LEGACY_WORK_DIR"
}

wait_for_node_ports_free() {
  local attempt port busy
  for attempt in {1..10}; do
    busy=0
    while IFS='|' read -r _ _ _ port _; do
      ss -lntH "sport = :${port}" 2>/dev/null | grep -q . && busy=1
    done <"$NODES_CONFIG"
    ((busy == 0)) && return 0
    sleep 1
  done
  return 1
}

service_belongs_to_project() {
  local service="$1" unit_file exec_start
  unit_file="$(systemctl show "$service" -p FragmentPath --value 2>/dev/null || true)"
  exec_start="$(systemctl show "$service" -p ExecStart --value 2>/dev/null || true)"
  is_project_service "$unit_file" ||
    [[ "$exec_start" == *"${WORK_DIR}/"* || "$exec_start" == *"${LEGACY_WORK_DIR}/"* ]]
}

stop_conflicting_sing_box_services() {
  local service
  systemctl stop "$SING_SERVICE" 2>/dev/null || true
  for service in "$LEGACY_SING_SERVICE" sba-singbox sing-box; do
    systemctl list-unit-files "${service}.service" --no-legend 2>/dev/null |
      grep -q "^${service}.service" || continue
    if service_belongs_to_project "$service"; then
      systemctl disable --now "$service" 2>/dev/null || true
      info "已停止占用节点端口的旧项目服务：${service}.service"
    fi
  done
}

stop_orphan_project_listeners() {
  local port line pid exe found=0
  while IFS='|' read -r _ _ _ port _; do
    while IFS= read -r line; do
      pid="$(sed -n 's/.*pid=\([0-9]\+\).*/\1/p' <<<"$line")"
      [[ -n "$pid" ]] || continue
      exe="$(readlink -f "/proc/${pid}/exe" 2>/dev/null || true)"
      case "$exe" in
        "${BIN_DIR}/sing-box"|"${LEGACY_WORK_DIR}/bin/sing-box"|"${LEGACY_WORK_DIR}/sing-box")
          kill "$pid" 2>/dev/null || true
          info "已停止遗留 sing-box 进程 PID ${pid}（端口 ${port}）。"
          found=1
          ;;
      esac
    done < <(ss -lntpH "sport = :${port}" 2>/dev/null || true)
  done <"$NODES_CONFIG"
  ((found == 0)) || sleep 1
}

report_node_port_owners() {
  local port
  while IFS='|' read -r _ _ _ port _; do
    ss -lntpH "sport = :${port}" 2>/dev/null || true
  done <"$NODES_CONFIG"
}

show_install_nodes() {
  section "明文节点"
  cat "$NODES_FILE"
  printf '\n'
}

install_project() {
  local install_mode="${1:-local}" installer_source latest_installer
  local work_backup="" sing_stage argo_stage file
  require_root
  control_panel
  subsection "安装 / 更新"
  if [[ "$install_mode" == "github" ]]; then
    latest_installer="$(mktemp)"
    info "正在获取 ${PROJECT_REPO} ${PROJECT_BRANCH} 的最新安装脚本。"
    fetch_latest_installer "$latest_installer"
    if ! cmp -s "$latest_installer" "$0"; then
      install -d -m 755 "$WORK_DIR"
      create_local_command "$latest_installer"
      rm -f "$latest_installer"
      green "本地脚本已更新，正在切换到新版继续安装。"
      exec bash "$LOCAL_SCRIPT" -i --github-refreshed
    fi
    rm -f "$latest_installer"
    green "当前安装脚本已是 GitHub 最新版本。"
  elif [[ "$install_mode" != "local" ]]; then
    die "未知安装模式：${install_mode}"
  fi
  migrate_legacy_install
  load_env
  prompt_install_values
  installer_source="$(mktemp)"
  install -m 755 "$0" "$installer_source"
  detect_arch
  install_dependencies
  assert_service_names_available
  install -d -m 755 "$WORK_DIR" "$BIN_DIR"
  install -d -m 700 "$BACKUP_DIR"
  for file in "$ENV_FILE" "$NODES_CONFIG" "$SING_BOX_CONFIG" "$NGINX_CONFIG" \
    "$LEGACY_NGINX_CONFIG" "$LOCAL_SCRIPT"; do
    if [[ -f "$file" ]]; then
      if [[ -z "$work_backup" ]]; then
        work_backup="${BACKUP_DIR}/config-previous"
        rm -rf "$work_backup"
        install -d -m 700 "$work_backup"
      fi
      cp -a "$file" "$work_backup/"
    fi
  done
  sing_stage="$(mktemp)"; argo_stage="$(mktemp)"
  stage_sing_box "$DEFAULT_SING_BOX_VERSION" "$sing_stage"
  stage_cloudflared "$argo_stage"
  install -m 755 "$sing_stage" "${BIN_DIR}/sing-box.new"
  install -m 755 "$argo_stage" "${BIN_DIR}/cloudflared.new"
  mv -f "${BIN_DIR}/sing-box.new" "${BIN_DIR}/sing-box"
  mv -f "${BIN_DIR}/cloudflared.new" "${BIN_DIR}/cloudflared"
  rm -f "$sing_stage" "$argo_stage"
  printf 'version=%s\n' "$VERSION" >"$MANAGED_FILE"
  save_env
  write_sing_box_config
  if [[ -f "$LEGACY_NGINX_CONFIG" ]] &&
    grep -q '/etc/sba/' "$LEGACY_NGINX_CONFIG" &&
    grep -qE '(/sba-sub|/sba-vl|/sba-vm|/sba-tr)' "$LEGACY_NGINX_CONFIG"; then
    rm -f "$LEGACY_NGINX_CONFIG"
  fi
  write_nginx_config
  write_services
  create_local_command "$installer_source"
  rm -f "$installer_source"
  systemctl daemon-reload
  systemctl enable nginx "$SING_SERVICE" "$ARGO_SERVICE"
  stop_conflicting_sing_box_services
  stop_orphan_project_listeners
  if ! wait_for_node_ports_free; then
    report_node_port_owners >&2
    die "节点端口仍被未知进程占用。为避免终止第三方服务，安装已停止。"
  fi
  systemctl restart nginx "$SING_SERVICE" "$ARGO_SERVICE"
  if wait_for_services; then
    remove_legacy_services
    remove_legacy_symlink
  else
    yellow "新服务尚未全部启动，已保留旧服务文件以便排查。"
    if ((LEGACY_MIGRATED)); then
      systemctl disable --now "$SING_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
      systemctl restart "$LEGACY_SING_SERVICE" "$LEGACY_ARGO_SERVICE" 2>/dev/null || true
      yellow "已先停用新服务再恢复旧服务，避免新旧 sing-box 同时抢占节点端口。"
    fi
  fi
  systemctl daemon-reload
  sync_argo_domain
  generate_nodes
  rm -f "$LEGACY_NODES_FILE" "$LEGACY_SBA_NODES_FILE"
  if health_check; then
    green "${PROJECT_NAME} 安装 / 更新完成，核心链路检查通过。"
  else
    yellow "${PROJECT_NAME} 文件已安装，但健康检查未全部通过；请先处理上述错误再使用节点。"
  fi
  section "运行摘要"
  state_value "Argo 服务" "$(service_status "$ARGO_SERVICE")"
  state_value "Sing-box 服务" "$(service_status "$SING_SERVICE")"
  key_value "Argo 域名" "$ARGO_DOMAIN"
  key_value "优选入口" "${SERVER}:${SERVER_PORT}"
  key_value "Argo 回源" "127.0.0.1:${ORIGIN_PORT}"
  key_value "组件版本" "$(component_versions)"
  state_value "WARP 分流" "$(warp_status)"
  key_value "节点文件" "$NODES_FILE"
  key_value "管理命令" "$COMMAND_NAME"
  show_install_nodes
}

install_menu() {
  local choice
  while true; do
    brand "${PROJECT_NAME} · 安装 / 更新"
    subsection "请选择安装来源"
    menu_item 1 "使用当前 VPS 本地脚本重装" "不更新项目脚本"
    menu_item 2 "从 GitHub 获取最新脚本安装" "可更新项目脚本"
    menu_item 0 "返回"
    ui_line
    read_choice "请选择："; choice="$REPLY"
    case "$choice" in
      1) install_project local; return ;;
      2) install_project github; return ;;
      0) return ;;
      *) yellow "请输入 0、1 或 2。" ;;
    esac
  done
}

begin_config_change() {
  CONFIG_SNAPSHOT="$(mktemp -d)"
  cp -a "$ENV_FILE" "$NODES_CONFIG" "$SING_BOX_CONFIG" "$NGINX_CONFIG" \
    "/etc/systemd/system/${SING_SERVICE}.service" "/etc/systemd/system/${ARGO_SERVICE}.service" \
    "$CONFIG_SNAPSHOT/" 2>/dev/null || true
}

apply_runtime_config() {
  local snapshot="${CONFIG_SNAPSHOT:-}"
  [[ -n "$snapshot" && -d "$snapshot" ]] || die "缺少配置事务快照。"
  if save_env && write_sing_box_config && write_nginx_config && write_services &&
    systemctl daemon-reload &&
    systemctl restart nginx "$SING_SERVICE" "$ARGO_SERVICE" && wait_for_services; then
    generate_nodes
    rm -rf "$snapshot"
    green "配置已校验并生效。"
    return 0
  fi
  red "新配置验证失败，正在恢复。"
  [[ -f "$snapshot/asb.env" ]] && install -m 600 "$snapshot/asb.env" "$ENV_FILE"
  [[ -f "$snapshot/nodes.conf" ]] && install -m 600 "$snapshot/nodes.conf" "$NODES_CONFIG"
  [[ -f "$snapshot/sing-box.json" ]] && install -m 600 "$snapshot/sing-box.json" "$SING_BOX_CONFIG"
  [[ -f "$snapshot/argo-singbox.conf" ]] && install -m 644 "$snapshot/argo-singbox.conf" "$NGINX_CONFIG"
  [[ -f "$snapshot/${SING_SERVICE}.service" ]] && install -m 600 "$snapshot/${SING_SERVICE}.service" "/etc/systemd/system/${SING_SERVICE}.service"
  [[ -f "$snapshot/${ARGO_SERVICE}.service" ]] && install -m 600 "$snapshot/${ARGO_SERVICE}.service" "/etc/systemd/system/${ARGO_SERVICE}.service"
  rm -rf "$snapshot"
  systemctl daemon-reload
  systemctl restart nginx "$SING_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
  die "配置未生效，已恢复修改前文件。"
}

list_node_profiles() {
  local tag protocol path port socks
  printf '%s%s标签              协议      WS 路径               端口    出站%s\n' \
    "$C_BOLD" "$C_BRIGHT_CYAN" "$C_RESET"
  printf '%s%s%s\n' "$C_DIM" '----------------  --------  --------------------  ------  ------' "$C_RESET"
  while IFS='|' read -r tag protocol path port socks; do
    printf '%s%-16s%s  %s%-8s%s  %-20s  %s%-6s%s  %s\n' \
      "$C_WHITE" "$tag" "$C_RESET" "$C_BRIGHT_MAGENTA" "$protocol" "$C_RESET" "$path" \
      "$C_BRIGHT_YELLOW" "$port" "$C_RESET" "${socks:-direct}"
  done <"$NODES_CONFIG"
}

add_node_profile() {
  local tag protocol path port socks default_port
  begin_config_change
  default_port="$(next_node_port)"
  read_input "节点标签（字母/数字/_/-）: " tag
  read_input "协议（vless/vmess/trojan）: " protocol
  protocol="${protocol,,}"
  read_input "WS 路径（以 / 开头）: " path
  read_input "本地监听端口 [${default_port}]: " port
  port="${port:-$default_port}"
  read_input "SOCKS5 出站（主机:端口:用户名:密码，留空为直连）: " socks
  [[ "$tag" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || die "节点标签格式错误。"
  [[ "$protocol" =~ ^(vless|vmess|trojan)$ ]] || die "协议不受支持。"
  valid_path "$path" || die "WS 路径格式错误。"
  valid_port "$port" || die "端口格式错误。"
  [[ -z "$socks" ]] || parse_socks5 "$socks" >/dev/null
  ! awk -F'|' -v tag="$tag" -v path="$path" -v port="$port" \
    '$1 == tag || $3 == path || $4 == port {found=1} END {exit !found}' "$NODES_CONFIG" ||
    die "节点标签、路径或端口已存在。"
  printf '%s|%s|%s|%s|%s\n' "$tag" "$protocol" "$path" "$port" "$socks" >>"$NODES_CONFIG"
  validate_nodes_config
  apply_runtime_config
}

change_origin_port() {
  local value temp next_port
  begin_config_change
  read_input "新的 Argo Tunnel 回源端口 [${ORIGIN_PORT}]: " value
  value="${value:-$ORIGIN_PORT}"
  valid_port "$value" || die "端口格式错误。"
  next_port="$((10#$value + 1))"
  ((next_port + $(wc -l <"$NODES_CONFIG") - 1 <= 65535)) ||
    die "端口过大，无法为全部节点顺延监听端口。"
  temp="$(mktemp)"
  awk -F'|' -v OFS='|' -v port="$next_port" '{$4=port++; print}' "$NODES_CONFIG" >"$temp"
  install -m 600 "$temp" "$NODES_CONFIG"
  rm -f "$temp"
  ORIGIN_PORT="$value"
  apply_runtime_config
  info "Cloudflare Public Hostname 的 Service 请同步改为 http://localhost:${ORIGIN_PORT}。"
}

delete_node_profile() {
  local tag temp
  list_node_profiles
  begin_config_change
  read_input "要删除的节点标签: " tag
  awk -F'|' -v wanted="$tag" '$1 == wanted {found=1} END {exit !found}' "$NODES_CONFIG" ||
    die "未找到节点标签：${tag}"
  [[ "$(wc -l <"$NODES_CONFIG")" -gt 1 ]] || die "至少必须保留一个节点。"
  temp="$(mktemp)"
  awk -F'|' -v wanted="$tag" '$1 != wanted' "$NODES_CONFIG" >"$temp"
  install -m 600 "$temp" "$NODES_CONFIG"
  rm -f "$temp"
  apply_runtime_config
}

edit_node_profile() {
  local wanted tag protocol path port socks new_tag new_protocol new_path new_port new_socks temp
  list_node_profiles
  read_input "要修改的节点标签: " wanted
  while IFS='|' read -r tag protocol path port socks; do
    [[ "$tag" == "$wanted" ]] && break
  done <"$NODES_CONFIG"
  [[ "${tag:-}" == "$wanted" ]] || die "未找到节点标签：${wanted}"
  begin_config_change
  read_input "新节点标签 [${tag}]: " new_tag
  read_input "新协议 [${protocol}]（vless/vmess/trojan）: " new_protocol
  read_input "新 WS 路径 [${path}]: " new_path
  read_input "新本地端口 [${port}]: " new_port
  read_input "新 SOCKS5 [${socks:-direct}]（留空保持，输入 - 改为直连）: " new_socks
  tag="${new_tag:-$tag}"; protocol="${new_protocol:-$protocol}"
  protocol="${protocol,,}"; path="${new_path:-$path}"; port="${new_port:-$port}"
  [[ "$new_socks" == "-" ]] && socks="" || socks="${new_socks:-$socks}"
  [[ "$tag" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || die "节点标签格式错误。"
  [[ "$protocol" =~ ^(vless|vmess|trojan)$ ]] || die "协议不受支持。"
  valid_path "$path" || die "WS 路径格式错误。"
  valid_port "$port" || die "端口格式错误。"
  [[ -z "$socks" ]] || parse_socks5 "$socks" >/dev/null
  ! awk -F'|' -v wanted="$wanted" -v tag="$tag" -v path="$path" -v port="$port" \
    '$1 != wanted && ($1 == tag || $3 == path || $4 == port) {found=1} END {exit !found}' "$NODES_CONFIG" ||
    die "节点标签、WS 路径或端口已被其他节点使用。"
  temp="$(mktemp)"
  awk -F'|' -v OFS='|' -v wanted="$wanted" -v tag="$tag" -v protocol="$protocol" \
    -v path="$path" -v port="$port" -v socks="$socks" \
    '$1 == wanted {$1=tag; $2=protocol; $3=path; $4=port; $5=socks} {print}' "$NODES_CONFIG" >"$temp"
  install -m 600 "$temp" "$NODES_CONFIG"; rm -f "$temp"
  validate_nodes_config
  apply_runtime_config
}

configure_warp() {
  local choice port targets domain normalized output item old_ifs
  while true; do
    section "WARP 网址分流"
    key_value "当前状态" "$([[ "$WARP_ENABLED" == "1" ]] && echo 已启用 || echo 未启用)"
    key_value "代理端口" "$WARP_PROXY_PORT"
    key_value "目标域名" "${WARP_DOMAINS:-无}"
    subsection "操作"
    menu_item 1 "启用 / 修改代理端口和全部域名"
    menu_item 2 "添加域名"
    menu_item 3 "删除域名"
    menu_item 4 "停用 WARP 分流"
    menu_item 0 "返回"
    read_choice "请选择："; choice="$REPLY"
    case "$choice" in
      1)
        install_cloudflare_warp
        read_input "WARP 本地 SOCKS5 端口 [${WARP_PROXY_PORT}]: " port
        port="${port:-$WARP_PROXY_PORT}"
        valid_port "$port" || die "WARP 代理端口无效。"
        read_input "走 WARP 的网址/域名（逗号分隔）[${WARP_DOMAINS:-无}]: " targets
        targets="${targets:-$WARP_DOMAINS}"
        targets="$(normalize_warp_domains "$targets")"
        systemctl enable --now warp-svc >/dev/null 2>&1 || die "无法启动 warp-svc。"
        ensure_warp_registration
        warp-cli --accept-tos mode proxy >/dev/null &&
          warp-cli --accept-tos proxy port "$port" >/dev/null &&
          warp-cli --accept-tos connect >/dev/null ||
          die "无法把 WARP 客户端切换到本地代理模式，请运行 warp-cli mode --help 检查客户端版本。"
        begin_config_change
        WARP_ENABLED=1; WARP_PROXY_PORT="$port"; WARP_DOMAINS="$targets"
        apply_runtime_config
        ;;
      2)
        [[ "$WARP_ENABLED" == "1" ]] || die "请先启用 WARP 分流。"
        key_value "已有域名" "$WARP_DOMAINS"
        read_input "要添加的网址/域名（可用逗号分隔）: " targets
        targets="$(normalize_warp_domains "$targets")"
        begin_config_change
        WARP_DOMAINS="$(normalize_warp_domains "${WARP_DOMAINS},${targets}")"
        apply_runtime_config
        ;;
      3)
        [[ "$WARP_ENABLED" == "1" ]] || die "WARP 分流尚未启用。"
        read_input "要删除的网址或域名: " domain
        normalized="$(normalize_warp_domains "$domain")"
        [[ "$normalized" != *,* ]] || die "每次只能删除一个域名。"
        output=""; old_ifs="$IFS"; IFS=','
        for item in $WARP_DOMAINS; do
          [[ "$item" == "$normalized" ]] || output+="${output:+,}${item}"
        done
        IFS="$old_ifs"
        [[ "$output" != "$WARP_DOMAINS" ]] || die "未找到 WARP 域名：${normalized}"
        [[ -n "$output" ]] || die "不能删除最后一个域名；如不再使用，请选择停用 WARP 分流。"
        begin_config_change
        WARP_DOMAINS="$output"
        apply_runtime_config
        ;;
      4)
        begin_config_change
        WARP_ENABLED=0; WARP_DOMAINS=""
        apply_runtime_config
        ;;
      0) return ;;
      *) yellow "无效选择。" ;;
    esac
  done
}

manage_config() {
  local choice value endpoint
  require_root
  load_env
  [[ -f "$ENV_FILE" ]] || die "${PROJECT_NAME} 尚未安装。"
  ensure_nodes_config
  while true; do
    brand "${PROJECT_NAME} · 集中配置"
    subsection "基础配置"
    menu_item 1 "Token / Argo 域名"
    menu_item 2 "Cloudflare 优选入口"
    menu_item 3 "Argo Tunnel 回源端口（节点端口依次顺延）"
    menu_item 4 "全局 UUID"
    section "节点与分流"
    menu_item 5 "查看节点"
    menu_item 6 "添加节点"
    menu_item 7 "修改节点"
    menu_item 8 "删除节点"
    menu_item 9 "WARP 网址分流"
    menu_item 0 "返回"
    ui_line
    read_choice "请选择："; choice="$REPLY"
    case "$choice" in
      1)
        begin_config_change
        read_input "新 Token [留空保持]: " value; ARGO_TOKEN="${value:-$ARGO_TOKEN}"
        read_input "新 Argo 域名 [${ARGO_DOMAIN}]: " value; ARGO_DOMAIN="${value:-$ARGO_DOMAIN}"
        valid_argo_token "$ARGO_TOKEN" && [[ "$ARGO_DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] ||
          die "Token 或域名无效。"
        apply_runtime_config
        ;;
      2) begin_config_change; read_input "新优选入口 域名/IP:端口: " endpoint; parse_endpoint "$endpoint"; apply_runtime_config ;;
      3) change_origin_port ;;
      4) begin_config_change; read_input "新 UUID: " value; valid_uuid "$value" || die "UUID 格式错误。"; UUID="$value"; apply_runtime_config ;;
      5) list_node_profiles ;;
      6) add_node_profile ;;
      7) edit_node_profile ;;
      8) delete_node_profile ;;
      9) configure_warp ;;
      0) return ;;
      *) yellow "请输入 0 到 9。" ;;
    esac
  done
}

backup_project() {
  local output="${1:-}" backup_dir temp_archive stage manifest_dir
  require_root
  [[ -f "$MANAGED_FILE" ]] || die "缺少项目所有权标记，拒绝备份。"
  [[ -f "$NODES_CONFIG" ]] || die "节点配置不存在：${NODES_CONFIG}"
  validate_nodes_config
  if [[ -z "$output" ]]; then
    read_input "请输入节点备份文件夹或 .tar.gz 路径 [${BACKUP_DIR}]: " output
    output="${output:-$BACKUP_DIR}"
  fi
  if [[ "$output" != *.tar.gz ]]; then
    backup_dir="${output%/}"
    [[ -n "$backup_dir" ]] || backup_dir="/"
    [[ "$backup_dir" == /* ]] || die "备份文件夹必须使用绝对路径。"
    [[ "$backup_dir" != "$WORK_DIR" ]] || die "备份不能直接保存到项目根目录。"
    if [[ "$backup_dir" == "$WORK_DIR/"* && "$backup_dir" != "$BACKUP_DIR" ]]; then
      die "项目目录内仅允许使用默认备份目录 ${BACKUP_DIR}。"
    fi
    install -d -m 700 "$backup_dir"
    output="${backup_dir}/asb-nodes-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
  fi
  [[ "$output" == /* ]] || die "备份路径必须使用绝对路径。"
  [[ "$output" != "$WORK_DIR" ]] || die "备份不能直接保存到项目根目录。"
  if [[ "$output" == "$WORK_DIR/"* && "$output" != "$BACKUP_DIR/"* ]]; then
    die "项目目录内仅允许使用默认备份目录 ${BACKUP_DIR}。"
  fi
  install -d -m 700 "$(dirname "$output")"
  [[ "$output" == *.tar.gz ]] || die "备份文件必须以 .tar.gz 结尾。"
  stage="$(mktemp -d)"
  manifest_dir="${stage}/asb-nodes-backup"
  install -d -m 700 "$manifest_dir"
  install -m 600 "$NODES_CONFIG" "${manifest_dir}/nodes.conf"
  {
    printf 'type=nodes\n'
    printf 'project=%s\n' "$PROJECT_NAME"
    printf 'version=%s\n' "$VERSION"
    printf 'created_at=%s\n' "$(date -Iseconds)"
    printf 'source=%s\n' "$NODES_CONFIG"
  } >"${manifest_dir}/manifest"
  chmod 600 "${manifest_dir}/manifest"
  temp_archive="$(mktemp --suffix=.tar.gz)"
  if ! tar -C "$stage" -czf "$temp_archive" "asb-nodes-backup"; then
    rm -rf "$stage"
    rm -f "$temp_archive"
    die "备份归档创建失败。"
  fi
  rm -rf "$stage"
  mv -f "$temp_archive" "$output"
  chmod 600 "$output"
  printf '\n'
  green "节点配置备份完成：${output}"
}

validate_backup_archive() {
  local archive="$1" members
  gzip -t "$archive" 2>/dev/null || die "备份归档 gzip 校验失败。"
  members="$(tar -tzf "$archive" 2>/dev/null)" || die "无法读取备份归档目录。"
  [[ -n "$members" ]] || die "备份归档为空。"
  if grep -E '(^|/)\.\.(/|$)|^/' <<<"$members" | grep -q .; then
    die "备份归档包含越界路径，拒绝恢复。"
  fi
  if tar -tvzf "$archive" 2>/dev/null | awk 'substr($1,1,1) !~ /^[-d]$/ {bad=1} END {exit !bad}'; then
    die "备份归档包含符号链接或其他特殊文件，拒绝恢复。"
  fi
  if ! grep -Eq '^(asb-nodes-backup|asb)/nodes\.conf$' <<<"$members"; then
    die "备份归档不包含可恢复的节点配置 nodes.conf。"
  fi
}

restore_project() {
  local archive="${1:-}" stage archive_copy latest nodes_source
  require_root
  if [[ -z "$archive" ]]; then
    read_input "请输入节点备份文件或目录 [${BACKUP_DIR}，留空使用最新备份]: " archive
    archive="${archive:-$BACKUP_DIR}"
  fi
  if [[ -d "$archive" ]]; then
    latest="$(find "$archive" -maxdepth 1 -type f \
      \( -name 'asb-nodes-backup-*.tar.gz' -o -name 'asb-backup-*.tar.gz' \) \
      -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n1 | cut -d' ' -f2-)"
    [[ -n "$latest" ]] || die "备份目录中没有可恢复的归档：${archive}"
    archive="$latest"
    info "使用最新备份：${archive}"
  fi
  [[ -f "$archive" ]] || die "备份文件不存在：${archive}"
  [[ -f "$MANAGED_FILE" ]] || die "当前 ${WORK_DIR} 缺少项目所有权标记，拒绝恢复节点配置。"
  archive_copy="$(mktemp --suffix=.tar.gz)"
  cp -a "$archive" "$archive_copy"
  validate_backup_archive "$archive_copy"
  stage="$(mktemp -d)"
  tar --no-same-owner --no-same-permissions -xzf "$archive_copy" -C "$stage"
  if [[ -f "$stage/asb-nodes-backup/nodes.conf" ]]; then
    nodes_source="$stage/asb-nodes-backup/nodes.conf"
  elif [[ -f "$stage/${WORK_DIR_NAME}/nodes.conf" ]]; then
    nodes_source="$stage/${WORK_DIR_NAME}/nodes.conf"
    yellow "检测到旧版完整备份，仅恢复其中的节点配置，不替换脚本或核心。"
  else
    rm -rf "$stage"; rm -f "$archive_copy"
    die "备份结构中缺少 nodes.conf。"
  fi
  begin_config_change
  install -m 600 "$nodes_source" "$NODES_CONFIG"
  if validate_nodes_config && apply_runtime_config; then
    rm -rf "$stage"
    rm -f "$archive_copy"
    printf '\n'
    green "节点配置恢复完成：${archive}"
    return 0
  fi
  [[ -f "$CONFIG_SNAPSHOT/nodes.conf" ]] && install -m 600 "$CONFIG_SNAPSHOT/nodes.conf" "$NODES_CONFIG"
  rm -rf "$CONFIG_SNAPSHOT"
  rm -rf "$stage"
  rm -f "$archive_copy"
  die "节点配置恢复失败，已回滚到恢复前状态。"
}

doctor() {
  local failed=0 token_in_unit=0 warp_target ip memory
  require_root
  load_env
  ensure_nodes_config
  ip="$(curl -4fsS --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null ||
    hostname -I 2>/dev/null | awk '{print $1}')"
  memory="$(free -m | awk '/^Mem:/{printf "%s/%s MiB (%.0f%%)",$3,$2,$3*100/$2}')"
  brand "${PROJECT_NAME} · 完整诊断"
  subsection "运行概览"
  key_value "公网 IP" "${ip:-未知}"
  key_value "脚本版本" "v${VERSION}"
  key_value "内存" "${memory:-未知}"
  key_value "优选入口" "${SERVER:-未知}:${SERVER_PORT:-未知}"
  key_value "Argo 回源" "127.0.0.1:${ORIGIN_PORT}"
  section "配置与组件"
  if validate_nodes_config && valid_uuid "$UUID" && valid_argo_token "$ARGO_TOKEN" &&
    [[ -n "$ARGO_DOMAIN" ]]; then
    green "项目配置：有效"
  else
    red "项目配置：无效"
    failed=1
  fi
  if "$BIN_DIR/sing-box" check -c "$SING_BOX_CONFIG" >/dev/null 2>&1; then green "Sing-box 配置：有效"; else red "Sing-box 配置：无效"; failed=1; fi
  if nginx -t >/dev/null 2>&1; then green "Nginx 配置：有效"; else red "Nginx 配置：无效"; failed=1; fi
  [[ -f "/etc/systemd/system/${ARGO_SERVICE}.service" ]] &&
    grep -Fq -- "--token ${ARGO_TOKEN}" "/etc/systemd/system/${ARGO_SERVICE}.service" && token_in_unit=1
  ((token_in_unit)) && green "Token：已配置且服务文件一致" || { red "Token：缺失或服务文件未同步"; failed=1; }
  key_value "组件版本" "$(component_versions)"
  if [[ "$WARP_ENABLED" == "1" ]]; then
    if systemctl is-active --quiet warp-svc &&
      ss -lntH "sport = :${WARP_PROXY_PORT}" | grep -q .; then
      green "WARP：本地代理运行于 127.0.0.1:${WARP_PROXY_PORT}"
    else
      red "WARP：服务或本地代理端口异常"
      failed=1
    fi
    warp_target="${WARP_DOMAINS%%,*}"
    if curl -fsS --socks5-hostname "127.0.0.1:${WARP_PROXY_PORT}" --connect-timeout 5 \
      --max-time 10 -o /dev/null "https://${warp_target}"; then
      green "WARP 目标测试：https://${warp_target}"
    else
      red "WARP 目标无法通过本地代理访问：https://${warp_target}"
      failed=1
    fi
  else
    info "WARP：未启用"
  fi
  health_check || failed=1
  section "最近日志"
  journalctl -u "$SING_SERVICE" -u "$ARGO_SERVICE" -n 30 --no-pager -o short-iso 2>/dev/null || true
  return "$failed"
}

show_nodes() {
  local node index=0 auto_url
  load_env
  [[ -f "$NODES_FILE" ]] || die "节点文件不存在，请先安装。"
  auto_url="https://${ARGO_DOMAIN}/${UUID}/auto"
  brand "${PROJECT_NAME} · 节点与订阅"
  subsection "配置文件索引"
  link_value "文件索引" "https://${ARGO_DOMAIN}/${UUID}/"
  link_value "自动适配" "$auto_url"
  link_value "原始明文" "https://${ARGO_DOMAIN}/${UUID}/raw"
  link_value "Base64" "https://${ARGO_DOMAIN}/${UUID}/base64"
  link_value "Clash" "https://${ARGO_DOMAIN}/${UUID}/clash"
  link_value "Clash Provider" "https://${ARGO_DOMAIN}/${UUID}/proxies"
  link_value "sing-box" "https://${ARGO_DOMAIN}/${UUID}/sing-box"
  link_value "Shadowrocket" "https://${ARGO_DOMAIN}/${UUID}/shadowrocket"
  if command -v qrencode >/dev/null 2>&1; then
    section "自动适配订阅 QR"
    qrencode -t ANSIUTF8 "$auto_url"
  fi
  section "明文节点"
  while IFS= read -r node; do
    ((index+=1))
    ((index > 1)) && printf '\n'
    printf '%s%s[节点 %d]%s\n%s\n' "$C_BOLD" "$C_BRIGHT_CYAN" "$index" "$C_RESET" "$node"
  done <"$NODES_FILE"
  printf '\n'
}

toggle_service() {
  local service="$1" label="$2"
  require_root
  systemctl list-unit-files "${service}.service" --no-legend 2>/dev/null | grep -q "^${service}.service" ||
    die "${label} 尚未安装。"
  if systemctl is-active --quiet "$service"; then
    systemctl disable --now "$service"
    yellow "${label} 已关闭。"
  else
    systemctl enable --now "$service"
    green "${label} 已开启。"
  fi
}

sync_versions() {
  local old_argo old_sing new_argo new_sing wanted_sing wanted_argo
  local sing_stage="" argo_stage="" backup_stamp answer update_sing=0 update_argo=0
  local services=()
  require_root
  [[ -f "$ENV_FILE" ]] || die "${PROJECT_NAME} 尚未安装。"
  [[ -f "/etc/systemd/system/${ARGO_SERVICE}.service" && -f "/etc/systemd/system/${SING_SERVICE}.service" ]] ||
    die "Argo 或 Sing-box 服务文件不存在，请先执行安装。"
  detect_arch
  old_argo="$(local_cloudflared_version || true)"
  old_sing="$(local_sing_box_version || true)"
  wanted_sing="$(get_sing_box_version)"
  wanted_argo="$(get_cloudflared_version)"
  new_sing="$wanted_sing"
  new_argo="$wanted_argo"
  section "Argo / cloudflared 核心"
  key_value "当前版本" "${old_argo:-未安装}"
  key_value "目标版本" "${new_argo:-未知}"
  if [[ "$old_argo" != "$new_argo" ]]; then
    read_input "是否更新 Argo / cloudflared？[y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] && update_argo=1
  else
    green "Argo / cloudflared 已是目标版本。"
  fi
  section "Sing-box 核心"
  key_value "当前版本" "${old_sing:-未安装}"
  key_value "目标版本" "${new_sing:-未知}"
  if [[ "$old_sing" != "$new_sing" ]]; then
    read_input "是否更新 Sing-box？[y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] && update_sing=1
  else
    green "Sing-box 已是目标版本。"
  fi
  if [[ "$old_sing" == "$new_sing" && "$old_argo" == "$new_argo" ]]; then
    return 0
  fi
  if ((update_sing == 0 && update_argo == 0)); then
    yellow "未选择需要更新的核心。"
    return 0
  fi
  if ((update_sing)); then
    sing_stage="$(mktemp)"
    stage_sing_box "$wanted_sing" "$sing_stage"
    "$sing_stage" check -c "$SING_BOX_CONFIG"
  fi
  if ((update_argo)); then
    argo_stage="$(mktemp)"
    stage_cloudflared "$argo_stage"
  fi
  backup_stamp="${BACKUP_DIR}/core-$(date +%Y%m%d-%H%M%S)"
  install -d -m 700 "$backup_stamp"
  ((update_sing)) && cp -a "$BIN_DIR/sing-box" "$backup_stamp/"
  ((update_argo)) && cp -a "$BIN_DIR/cloudflared" "$backup_stamp/"
  if ((update_sing)); then
    install -m 755 "$sing_stage" "${BIN_DIR}/sing-box.new"
    mv -f "${BIN_DIR}/sing-box.new" "$BIN_DIR/sing-box"
    services+=("$SING_SERVICE")
  fi
  if ((update_argo)); then
    install -m 755 "$argo_stage" "${BIN_DIR}/cloudflared.new"
    mv -f "${BIN_DIR}/cloudflared.new" "$BIN_DIR/cloudflared"
    services+=("$ARGO_SERVICE")
  fi
  rm -f "$sing_stage" "$argo_stage"
  if systemctl restart "${services[@]}" &&
    wait_for_services && "$BIN_DIR/sing-box" check -c "$SING_BOX_CONFIG"; then
    rm -rf "$backup_stamp"
    printf '\n'
    ((update_argo)) && green "Argo / cloudflared 更新成功：${old_argo:-无} → ${new_argo}"
    ((update_sing)) && green "Sing-box 更新成功：${old_sing:-无} → ${new_sing}"
    return 0
  else
    red "更新后验证失败，正在自动回滚。"
    ((update_sing)) && install -m 755 "$backup_stamp/sing-box" "$BIN_DIR/sing-box"
    ((update_argo)) && install -m 755 "$backup_stamp/cloudflared" "$BIN_DIR/cloudflared"
    systemctl restart "${services[@]}" || true
    wait_for_services || true
    die "核心已回滚到更新前版本，请查看 journalctl。"
  fi
}

manage_bbr() {
  require_root
  command -v curl >/dev/null 2>&1 || die "缺少 curl，无法启动 BBR/内核管理脚本。"
  yellow "第三方工具：升级内核、安装 BBR、DD 系统均由 ylx2016/Linux-NetSpeed 脚本提供，本项目不维护其内容。"
  bash <(curl -fsSL --retry 3 --connect-timeout 10 \
    https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh)
}

restart_services() {
  require_root
  systemctl restart nginx "$SING_SERVICE" "$ARGO_SERVICE"
  green "服务已重启。"
}

purge_installed_packages() {
  local package installed=()
  for package in "$@"; do
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null |
      grep -q '^install ok installed$' && installed+=("$package")
  done
  ((${#installed[@]} > 0)) || return 0
  apt-get purge -y "${installed[@]}"
}

uninstall_project() {
  local legacy_link target answer resolved_work_dir remove_nginx=0 remove_warp=0 remove_tools=0
  require_root
  [[ -f "$MANAGED_FILE" ]] || die "缺少项目所有权标记，拒绝自动卸载；请人工核对 ${WORK_DIR}。"
  resolved_work_dir="$(readlink -f "$WORK_DIR" 2>/dev/null || true)"
  [[ "$resolved_work_dir" == "$WORK_DIR" ]] ||
    die "项目目录解析结果异常，拒绝递归删除：${WORK_DIR}"
  yellow "将删除本项目服务、私有 Argo/cloudflared 与 sing-box 核心、配置、订阅、备份和命令入口。"
  read_input "确认彻底卸载 ${PROJECT_NAME}？[y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { yellow "已取消卸载。"; return 0; }
  if command -v nginx >/dev/null 2>&1 ||
    dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -q 'install ok installed'; then
    read_input "同时卸载 Nginx？可能被其他网站使用，默认保留 [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] && remove_nginx=1
  fi
  if command -v warp-cli >/dev/null 2>&1 ||
    dpkg-query -W -f='${Status}' cloudflare-warp 2>/dev/null | grep -q 'install ok installed' ||
    [[ -e /etc/apt/sources.list.d/cloudflare-client.list ||
      -e /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg ]]; then
    read_input "同时卸载 Cloudflare WARP 客户端、注册与软件源？默认保留 [y/N]: " answer
    [[ "$answer" =~ ^[Yy]$ ]] && remove_warp=1
  fi
  read_input "同时卸载脚本使用的通用工具 curl/ca-certificates/openssl/tar/qrencode/gnupg？可能被其他程序使用，默认保留 [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] && remove_tools=1

  systemctl disable --now "$SING_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
  rm -f "/etc/systemd/system/${SING_SERVICE}.service" "/etc/systemd/system/${ARGO_SERVICE}.service"
  remove_legacy_services
  rm -f "$NGINX_CONFIG" "$LEGACY_NGINX_CONFIG" "/usr/local/bin/${COMMAND_NAME}" \
    "$NODES_FILE" "$LEGACY_NODES_FILE" "$LEGACY_SBA_NODES_FILE"
  for legacy_link in /usr/local/bin/sb /usr/local/bin/argo-singbox; do
    [[ -L "$legacy_link" ]] || continue
    target="$(readlink -f "$legacy_link" 2>/dev/null || true)"
    [[ "$target" == "$LOCAL_SCRIPT" ]] && rm -f "$legacy_link"
  done
  remove_legacy_symlink
  rm -f "$ENV_FILE" "$NODES_CONFIG" "$SING_BOX_CONFIG" "$LOCAL_SCRIPT" "$MANAGED_FILE" \
    "$SUB_FILE" "$SUB_BASE64_FILE" "$SUB_CLASH_FILE" "$SUB_CLASH_PROVIDER_FILE" \
    "$SUB_SING_BOX_FILE" "$SUB_SHADOWROCKET_FILE" "$SUB_AUTO_QR_FILE" \
    "$BIN_DIR/sing-box" "$BIN_DIR/cloudflared"
  rm -rf "$BACKUP_DIR"
  rm -rf "$resolved_work_dir"

  if ((remove_warp)); then
    warp-cli --accept-tos disconnect >/dev/null 2>&1 || true
    warp-cli --accept-tos registration delete >/dev/null 2>&1 || true
    systemctl disable --now warp-svc 2>/dev/null || true
    purge_installed_packages cloudflare-warp >/dev/null 2>&1 ||
      yellow "cloudflare-warp 软件包卸载失败，请手工检查。"
    rm -f /etc/apt/sources.list.d/cloudflare-client.list \
      /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
  fi
  if ((remove_nginx)); then
    systemctl disable --now nginx 2>/dev/null || true
    purge_installed_packages nginx nginx-common nginx-core nginx-full nginx-light >/dev/null 2>&1 ||
      yellow "Nginx 软件包卸载失败，请手工检查。"
  else
    systemctl restart nginx 2>/dev/null || true
  fi
  if ((remove_tools)); then
    purge_installed_packages curl ca-certificates openssl tar qrencode gnupg >/dev/null 2>&1 ||
      yellow "部分通用工具卸载失败，请手工检查。"
  fi
  systemctl daemon-reload
  green "${PROJECT_NAME} 已彻底卸载；本次脚本执行结束。"
  exit 0
}

menu() {
  while true; do
    load_env
    control_panel
    subsection "运行概览"
    state_value "Argo 服务" "$(service_status "$ARGO_SERVICE")"
    state_value "Sing-box 服务" "$(service_status "$SING_SERVICE")"
    if [[ -n "$ARGO_DOMAIN" ]]; then
      key_value "Argo 域名" "$ARGO_DOMAIN"
      key_value "优选入口" "${SERVER}:${SERVER_PORT}"
      key_value "Argo 回源" "127.0.0.1:${ORIGIN_PORT}"
    fi
    key_value "组件版本" "$(component_versions)"
    state_value "WARP 分流" "$(warp_status)"
    brand "${PROJECT_NAME} · 控制中心"
    section "日常管理"
    menu_item 1 "查看节点信息" "${COMMAND_NAME} -n"
    menu_item 2 "开启/关闭 Argo" "${COMMAND_NAME} -a"
    menu_item 3 "开启/关闭 Sing-box" "${COMMAND_NAME} -s"
    menu_item 4 "集中配置" "${COMMAND_NAME} -c"
    menu_item 5 "重启全部服务" "${COMMAND_NAME} -r"
    menu_item 6 "完整诊断" "${COMMAND_NAME} -x"
    section "维护工具"
    menu_item 7 "安装 / 更新 ${PROJECT_NAME}" "${COMMAND_NAME} -i"
    menu_item 8 "更新 Argo / Sing-box 核心" "${COMMAND_NAME} -v"
    menu_item 9 "备份节点配置" "${COMMAND_NAME} -k"
    menu_item 10 "恢复节点配置" "${COMMAND_NAME} -l"
    menu_item 11 "第三方 BBR / DD 工具" "${COMMAND_NAME} -b"
    menu_item 12 "卸载 ${PROJECT_NAME}" "${COMMAND_NAME} -u"
    menu_item 0 "退出"
    ui_line
    read_choice "请选择："; choice="$REPLY"
    case "$choice" in
      1) show_nodes ;;
      2) toggle_service "$ARGO_SERVICE" Argo ;;
      3) toggle_service "$SING_SERVICE" Sing-box ;;
      4) manage_config ;;
      5) restart_services ;;
      6) doctor ;;
      7) install_menu ;;
      8) sync_versions ;;
      9) backup_project ;;
      10) restore_project ;;
      11) manage_bbr ;;
      12) uninstall_project ;;
      0) exit 0 ;;
      *) yellow "请输入 0 到 12。" ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    -n) show_nodes ;;
    -a) toggle_service "$ARGO_SERVICE" Argo ;;
    -s) toggle_service "$SING_SERVICE" Sing-box ;;
    -c) manage_config ;;
    -r) restart_services ;;
    -x) doctor ;;
    -i)
      if [[ "${2:-}" == "--github-refreshed" ]]; then
        install_project local
      elif [[ -n "${2:-}" ]]; then
        die "未知安装参数：${2}"
      else
        install_menu
      fi
      ;;
    -v) sync_versions ;;
    -k) backup_project "${2:-}" ;;
    -l) restore_project "${2:-}" ;;
    -b) manage_bbr ;;
    -u) uninstall_project ;;
    "") menu ;;
    *) die "未知参数。可用参数：-n、-a、-s、-c、-r、-x、-i、-v、-k、-l、-b、-u。" ;;
  esac
fi
