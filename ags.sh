#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="1.3.3"
PROJECT_NAME="AGS"
PROJECT_CODE="AGS"
COMMAND_NAME="ags"
COMMAND_NAME_UPPER="AGS"
PROJECT_REPO="Fiatnorm/AGS"
PROJECT_BRANCH="main"
SING_BOX_REPO="SagerNet/sing-box"
TCP_BRUTAL_REPO="apernet/tcp-brutal"
TCP_BRUTAL_INSTALLER_REV="f11e52d88c7ad2285896de018c2d96d4687f0ab6"
TCP_BRUTAL_INSTALLER_SHA256="cd7615dd64836d8b239124cad776ac9e5a330830147e1a6892cb69e1ae6c9de6"
TCP_BRUTAL_VERSION="1.0.3"
TCP_BRUTAL_DKMS_SHA256="38526721f2e8a8c1907eb289d80526fc2bee9ca09b1f89d91362cea8ef1aad04"
WORK_DIR="/etc/ags"
WORK_DIR_NAME="${WORK_DIR##*/}"
PREVIOUS_WORK_DIR="/etc/argo-singbox"
LEGACY_WORK_DIR="/etc/asb"
CONFIG_DIR="${WORK_DIR}/config"
DATA_DIR="${WORK_DIR}/data"
SUBSCRIPTION_DIR="${WORK_DIR}/subscriptions"
ENV_FILE="${CONFIG_DIR}/ags.env"
SING_BOX_CONFIG="${CONFIG_DIR}/sing-box.json"
NGINX_CONFIG="/etc/nginx/conf.d/ags.conf"
LEGACY_NGINX_CONFIG="/etc/nginx/conf.d/argo-singbox.conf"
OLDER_NGINX_CONFIG="/etc/nginx/conf.d/argofusion.conf"
NODES_FILE="${DATA_DIR}/nodes.txt"
LEGACY_NODES_FILE="/root/argo-singbox_nodes.txt"
LOCAL_SCRIPT="${WORK_DIR}/ags.sh"
BIN_DIR="${WORK_DIR}/bin"
BACKUP_DIR="${WORK_DIR}/backup"
MANAGED_FILE="${WORK_DIR}/managed"
NODES_CONFIG="${CONFIG_DIR}/nodes.conf"
TRAFFIC_DB="${DATA_DIR}/traffic.db"
TRAFFIC_ERROR_FILE="${DATA_DIR}/traffic.last_error"
SUB_FILE="${SUBSCRIPTION_DIR}/subscription.txt"
SUB_BASE64_FILE="${SUBSCRIPTION_DIR}/subscription.base64"
SUB_CLASH_FILE="${SUBSCRIPTION_DIR}/subscription.clash.yaml"
SUB_SING_BOX_FILE="${SUBSCRIPTION_DIR}/subscription.sing-box.json"
SUB_AUTO_QR_FILE="${SUBSCRIPTION_DIR}/subscription.auto.svg"
CORE_SERVICE="ags-core"
ARGO_SERVICE="ags-tunnel"
TRAFFIC_SERVICE="ags-traffic"
TRAFFIC_TIMER="ags-traffic"
PREVIOUS_CORE_SERVICE="argo-singbox-core"
PREVIOUS_ARGO_SERVICE="argo-singbox-tunnel"
PREVIOUS_TRAFFIC_SERVICE="argo-singbox-traffic"
PREVIOUS_TRAFFIC_TIMER="argo-singbox-traffic"
LEGACY_CORE_SERVICE="asb-core"
LEGACY_ARGO_SERVICE="asb-tunnel"
LEGACY_MIGRATED=0

DEFAULT_SERVER="bestcf.cdn.fiatnorm.us.kg"
DEFAULT_SERVER_PORT="443"
# 固定为已核验的官方最新稳定版，不跟随预发布。
DEFAULT_SING_BOX_VERSION="1.13.18"
DEFAULT_CLOUDFLARED_VERSION="2026.7.3"

DEFAULT_ORIGIN_PORT=3010
DEFAULT_STATS_API_PORT=18085
DEFAULT_BRUTAL_UP_MBPS=1000
DEFAULT_BRUTAL_DOWN_MBPS=1000
MULTIPLEX_MAX_STREAMS=16
ORIGIN_PORT="$DEFAULT_ORIGIN_PORT"
IS_BRUTAL=false

UI_WIDTH=64
if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_UNDERLINE=$'\033[4m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_MAGENTA=$'\033[35m'; C_CYAN=$'\033[36m'; C_WHITE=$'\033[37m'
  C_BRIGHT_RED=$'\033[91m'; C_BRIGHT_GREEN=$'\033[92m'; C_BRIGHT_YELLOW=$'\033[93m'
  C_BRIGHT_BLUE=$'\033[94m'; C_BRIGHT_MAGENTA=$'\033[95m'; C_BRIGHT_CYAN=$'\033[96m'
  C_BRIGHT_WHITE=$'\033[97m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_UNDERLINE=""; C_RED=""; C_GREEN=""; C_YELLOW=""
  C_BLUE=""; C_MAGENTA=""; C_CYAN=""; C_WHITE=""; C_BRIGHT_RED=""; C_BRIGHT_GREEN=""
  C_BRIGHT_YELLOW=""; C_BRIGHT_BLUE=""; C_BRIGHT_MAGENTA=""; C_BRIGHT_CYAN=""
  C_BRIGHT_WHITE=""
fi
ui_line() {
  local char="${1:--}"
  UI_LAST_WAS_LINE=1
  printf '%s%*s%s\n' "$C_BRIGHT_BLUE" "$UI_WIDTH" '' "$C_RESET" | tr ' ' "$char"
}
green() { printf '%s✓ %s%s\n' "$C_BRIGHT_GREEN" "$*" "$C_RESET"; }
yellow() { printf '%s! %s%s\n' "$C_BRIGHT_YELLOW" "$*" "$C_RESET"; }
red() { printf '%s✗ %s%s\n' "$C_BRIGHT_RED" "$*" "$C_RESET" >&2; }
info() { printf '%s• %s%s\n' "$C_BRIGHT_CYAN" "$*" "$C_RESET"; }
display_width() {
  local text="$1" bytes chars
  bytes="$(printf '%s' "$text" | wc -c)"
  chars="$(printf '%s' "$text" | LC_ALL=C.UTF-8 wc -m)"
  printf '%s' "$((chars + (bytes - chars) / 2))"
}
pad_right() {
  local text="$1" target="$2" width pad
  width="$(display_width "$text")"
  pad=$((target - width))
  ((pad < 0)) && pad=0
  printf '%s%*s' "$text" "$pad" ''
}
fit_text() {
  local text="$1" target="$2"
  if (( $(display_width "$text") > target )); then
    printf '%s~' "${text:0:$((target - 1))}"
  else
    pad_right "$text" "$target"
  fi
}
ui_page() {
  local title="$1" mode="${2:-none}" hint="" hint_text="" title_width hint_width padding
  case "$mode" in
    main) hint_text="退出" ;;
    back) hint_text="返回" ;;
    cancel) hint_text="取消" ;;
    default) hint="Enter · 默认 | 0 · 取消" ;;
    none) ;;
    *) die "未知页面提示模式：${mode}" ;;
  esac
  [[ -z "$hint_text" ]] || hint="0 · ${hint_text}"
  printf '\n%s%s◆ %s%s' "$C_BOLD" "$C_BRIGHT_MAGENTA" "$title" "$C_RESET"
  if [[ -n "$hint" ]]; then
    title_width="$(display_width "$title")"
    hint_width="$(display_width "$hint")"
    padding=$((UI_WIDTH - 2 - title_width - hint_width))
    if ((padding >= 2)); then
      if [[ "$mode" == "default" ]]; then
        printf '%*s%sEnter%s · %s%s%s %s|%s %s0%s · %s取消%s\n' "$padding" '' \
          "$C_BRIGHT_YELLOW" "$C_BRIGHT_WHITE" \
          "默认" "$C_RESET" \
          "$C_BRIGHT_WHITE" "$C_RESET" "$C_BRIGHT_YELLOW" "$C_BRIGHT_WHITE" "$C_RESET"
      else
        printf '%*s%s0%s · %s%s\n' "$padding" '' "$C_BRIGHT_YELLOW" "$C_BRIGHT_WHITE" \
          "$hint_text" "$C_RESET"
      fi
    else
      if [[ "$mode" == "default" ]]; then
        printf '\n  %sEnter%s · %s%s%s %s|%s %s0%s · %s取消%s\n' \
          "$C_BRIGHT_YELLOW" "$C_BRIGHT_WHITE" \
          "默认" "$C_RESET" \
          "$C_BRIGHT_WHITE" "$C_RESET" "$C_BRIGHT_YELLOW" "$C_BRIGHT_WHITE" "$C_RESET"
      else
        printf '\n  %s0%s · %s%s\n' "$C_BRIGHT_YELLOW" "$C_BRIGHT_WHITE" "$hint_text" "$C_RESET"
      fi
    fi
  else
    printf '\n'
  fi
  ui_line
}
brand() { ui_page "$1" "${2:-none}"; }
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
  ip="$(public_ipv4)"
  printf '%s · %s · IP %s%s%s' "$os" "$arch" "$C_BRIGHT_MAGENTA" "${ip:-未知}" "$C_RESET"
}
public_ipv4() {
  curl -4fsS --connect-timeout 2 --max-time 3 https://api.ipify.org 2>/dev/null ||
    hostname -I 2>/dev/null | awk '{print $1}' || true
}
node_overview() {
  [[ -s "$NODES_CONFIG" ]] || { printf 'Vless 0 · Vmess 0 · Trojan 0'; return; }
  awk -F'|' '
    {protocols[$2]++}
    END {
      printf "Vless %d · Vmess %d · Trojan %d", protocols["vless"], protocols["vmess"], protocols["trojan"]
    }
  ' "$NODES_CONFIG"
}
control_panel() {
  printf '\n%s%s' "$C_BOLD" "$C_BRIGHT_CYAN"
  printf '%s\n' '    ___                     _____ _             __'
  printf '%s\n' '   /   |  _________ _____  / ___/(_)___  ____ _/ /_  ____  _  __'
  printf '%s\n' '  / /| | / ___/ __ `/ __ \ \__ \/ / __ \/ __ `/ __ \/ __ \| |/_/'
  printf '%s\n' ' / ___ |/ /  / /_/ / /_/ /___/ / / / / / /_/ / /_/ / /_/ />  <'
  printf '%s\n' '/_/  |_/_/   \__, /\____//____/_/_/ /_/\__, /_.___/\____/_/|_|'
  printf '%s\n' '            /____/                    /____/'
  printf '\n%s%s%s  %s%s v%s%s %s· Argo Tunnel · Sing-box · WS%s\n' \
    "$C_BOLD" "$C_BRIGHT_MAGENTA" "$PROJECT_NAME" "$C_BRIGHT_YELLOW" "$PROJECT_CODE" "$VERSION" \
    "$C_RESET" "$C_DIM" "$C_RESET"
  printf '%s' "$C_BRIGHT_CYAN"
  pad_right "系统环境" 12
  printf '%s %s%s%s\n' "$C_RESET" "$C_WHITE" "$(system_summary)" "$C_RESET"
  ui_line
  UI_TIGHT_SECTION=1
}
control_panel() {
  printf '\n%s%s' "$C_BOLD" "$C_BRIGHT_CYAN"
  printf '%s\n' '    ___                     ______           _'
  printf '%s\n' '   /   |  _________  ____  / ____/_  _______(_)___  ____'
  printf '%s\n' '  / /| | / ___/ __ \/ __ \/ /_  / / / / ___/ / __ \/ __ \'
  printf '%s\n' ' / ___ |/ /  / /_/ / /_/ / __/ / /_/ (__  ) / /_/ / / / /'
  printf '%s\n' '/_/  |_|_/   \__, /\____/_/    \__,_/____/_/\____/_/ /_/'
  printf '%s\n' '            /____/'
  printf '\n%s%s%s  %s%s v%s%s %s· Argo Tunnel · Sing-box · WS%s\n' \
    "$C_BOLD" "$C_BRIGHT_MAGENTA" "$PROJECT_NAME" "$C_BRIGHT_YELLOW" "$PROJECT_CODE" "$VERSION" \
    "$C_RESET" "$C_DIM" "$C_RESET"
  printf '%s' "$C_BRIGHT_CYAN"
  pad_right "系统环境" 12
  printf '%s%s%s%s\n' "$C_RESET" "$C_BRIGHT_WHITE" "$(system_summary)" "$C_RESET"
  ui_line
  UI_TIGHT_SECTION=1
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
service_label() {
  case "$1" in
    nginx) printf 'Nginx' ;;
    "$CORE_SERVICE") printf '%s Core' "$(core_label)" ;;
    "$ARGO_SERVICE") printf 'Argo Tunnel' ;;
    *) printf '%s' "$1" ;;
  esac
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
  printf '%s %s · %s %s · CF %s' "$PROJECT_CODE" "$VERSION" "$(core_label)" \
    "$(local_core_version 2>/dev/null || printf '未安装')" \
    "$(local_cloudflared_version 2>/dev/null || printf '未安装')"
}
section() {
  if [[ "${UI_TIGHT_SECTION:-0}" == "1" || "${UI_LAST_WAS_LINE:-0}" == "1" ]]; then
    UI_TIGHT_SECTION=0
  else
    printf '\n'
  fi
  UI_LAST_WAS_LINE=0
  printf '%s%s▸ %s%s\n' "$C_BOLD" "$C_BRIGHT_BLUE" "$*" "$C_RESET"
}
subsection() { section "$*"; }
key_value() {
  printf '%s' "$C_BRIGHT_CYAN"
  pad_right "$1" 13
  printf '%s  %s%s%s\n' "$C_RESET" "$C_BRIGHT_WHITE" "$2" "$C_RESET"
}
ip_value() {
  printf '%s' "$C_BRIGHT_CYAN"
  pad_right "$1" 13
  printf '%s  %s%s%s\n' "$C_RESET" "$C_BRIGHT_MAGENTA" "$2" "$C_RESET"
}
endpoint_value() {
  local label="$1" host="$2" port="$3" color="$C_BRIGHT_WHITE" display_host="$2"
  [[ "$host" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ || "$host" =~ ^[0-9A-Fa-f:]+$ ]] && color="$C_BRIGHT_MAGENTA"
  [[ "$host" == *:* && "$host" != \[*\] ]] && display_host="[${host}]"
  printf '%s' "$C_BRIGHT_CYAN"
  pad_right "$label" 13
  printf '%s  %s%s:%s%s\n' "$C_RESET" "$color" "$display_host" "$port" "$C_RESET"
}
state_value() {
  local color="$C_BRIGHT_YELLOW" value="$2" status core endpoint
  case "$2" in
    运行中*|*'· 运行中') color="$C_BRIGHT_GREEN" ;;
    已配置) color="$C_BRIGHT_GREEN" ;;
    未配置|未启用|已停止|未安装) color="$C_BRIGHT_YELLOW" ;;
    *异常*) color="$C_BRIGHT_RED" ;;
  esac
  printf '%s' "$C_BRIGHT_CYAN"
  pad_right "$1" 13
  if [[ "$1" == "代理核心" && "$value" =~ ^([^·]+)[[:space:]]·[[:space:]](.*)$ ]]; then
    status="${BASH_REMATCH[1]}"; core="${BASH_REMATCH[2]}"
    printf '%s  %s%s%s %s·%s %s%s%s\n' "$C_RESET" "$color" "$status" "$C_RESET" \
      "$C_BRIGHT_WHITE" "$C_RESET" "$C_BRIGHT_MAGENTA" "$core" "$C_RESET"
  elif [[ ("$1" == "WARP" || "$1" == "WARP 分流") && "$value" =~ ^([^·]+)[[:space:]]·[[:space:]](127\.0\.0\.1:[0-9]+)$ ]]; then
    status="${BASH_REMATCH[1]}"; endpoint="${BASH_REMATCH[2]}"
    printf '%s  %s%s%s %s·%s %s%s%s\n' "$C_RESET" "$color" "$status" "$C_RESET" \
      "$C_BRIGHT_WHITE" "$C_RESET" "$C_BRIGHT_WHITE" "$endpoint" "$C_RESET"
  else
    printf '%s  %s%s%s\n' "$C_RESET" "$color" "$value" "$C_RESET"
  fi
}
link_value() {
  printf '%s' "$C_BRIGHT_CYAN"
  pad_right "$1" 18
  printf '%s  %s%s%s%s\n' "$C_RESET" "$C_BRIGHT_WHITE" "$C_UNDERLINE" "$2" "$C_RESET"
}
prompt() { printf '%s%s› %s%s' "$C_BOLD" "$C_BRIGHT_MAGENTA" "$*" "$C_RESET"; }
read_choice() { prompt "$1"; IFS= read -r REPLY; REPLY="${REPLY%$'\r'}"; }
read_input() { prompt "$1"; IFS= read -r "$2"; printf -v "$2" '%s' "${!2%$'\r'}"; }
is_exit_input() {
  case "${1:-}" in
    0) return 0 ;;
    *) return 1 ;;
  esac
}
is_confirmed() { [[ -z "${1:-}" || "${1:-}" =~ ^[Yy]$ ]]; }
return_notice() { :; }

cancel_config_change() {
  [[ -n "${CONFIG_SNAPSHOT:-}" && -d "$CONFIG_SNAPSHOT" ]] && rm -rf "$CONFIG_SNAPSHOT"
  unset CONFIG_SNAPSHOT
  yellow "已取消修改，配置未变更。"
}
menu_item() {
  printf '  %s%2s%s  %s' "$C_BRIGHT_YELLOW" "$1" "$C_RESET" "$C_BRIGHT_WHITE"
  pad_right "$2" 28
  printf '%s%s%s%s\n' "$C_RESET" "$C_BRIGHT_CYAN" "${3:+[$3]}" "$C_RESET"
}
menu_hint() {
  printf '  %s•%s %s%s%s\n' "$C_BRIGHT_CYAN" "$C_RESET" "$C_DIM" "$*" "$C_RESET"
}
protocol_label() {
  case "$1" in
    vless) printf 'Vless' ;;
    vmess) printf 'Vmess' ;;
    trojan) printf 'Trojan' ;;
    *) printf '%s' "$1" ;;
  esac
}

node_type_label() {
  case "$1" in
    vless) printf 'Vless+WS+TLS' ;;
    vmess) printf 'Vmess+WS+TLS' ;;
    trojan) printf 'Trojan+WS+TLS' ;;
    *) printf '%s' "$1" ;;
  esac
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
  CORE="sing-box"
  STATS_API_PORT="${STATS_API_PORT:-$DEFAULT_STATS_API_PORT}"
  BRUTAL_UP_MBPS="${BRUTAL_UP_MBPS:-$DEFAULT_BRUTAL_UP_MBPS}"
  BRUTAL_DOWN_MBPS="${BRUTAL_DOWN_MBPS:-$DEFAULT_BRUTAL_DOWN_MBPS}"
}

ensure_project_layout() {
  install -d -m 700 "$CONFIG_DIR" "$DATA_DIR"
  install -d -m 755 "$SUBSCRIPTION_DIR"
}

verify_project_file_relocation() {
  local source="$1" destination="$2"
  [[ -e "$source" ]] || return 0
  [[ -f "$source" && ! -L "$source" ]] ||
    die "旧目录中的项目文件类型异常，拒绝迁移：${source}"
  if [[ -e "$destination" ]]; then
    [[ -f "$destination" && ! -L "$destination" ]] ||
      die "新目录中的项目文件类型异常，拒绝迁移：${destination}"
    cmp -s "$source" "$destination" ||
      die "新旧目录中的项目文件内容不同，拒绝覆盖：${source}"
  fi
}

relocate_project_file() {
  local source="$1" destination="$2" mode="$3"
  [[ -e "$source" ]] || return 0
  if [[ -e "$destination" ]]; then
    rm -f -- "$source"
  else
    mv -- "$source" "$destination"
  fi
  chmod "$mode" "$destination"
}

migrate_project_layout() {
  local moved=0
  [[ -f "$MANAGED_FILE" ]] || return 0

  if [[ -f "${CONFIG_DIR}/argo-singbox.env" && -f "${WORK_DIR}/argo-singbox.env" ]] &&
    ! cmp -s "${CONFIG_DIR}/argo-singbox.env" "${WORK_DIR}/argo-singbox.env"; then
    die "检测到两份内容不同的旧配置，拒绝自动合并。"
  fi
  verify_project_file_relocation "${CONFIG_DIR}/argo-singbox.env" "$ENV_FILE"
  verify_project_file_relocation "${WORK_DIR}/argo-singbox.env" "$ENV_FILE"
  verify_project_file_relocation "${WORK_DIR}/nodes.conf" "$NODES_CONFIG"
  verify_project_file_relocation "${WORK_DIR}/sing-box.json" "$SING_BOX_CONFIG"
  verify_project_file_relocation "${WORK_DIR}/nodes.txt" "$NODES_FILE"
  verify_project_file_relocation "${WORK_DIR}/subscription.txt" "$SUB_FILE"
  verify_project_file_relocation "${WORK_DIR}/subscription.base64" "$SUB_BASE64_FILE"
  verify_project_file_relocation "${WORK_DIR}/subscription.clash.yaml" "$SUB_CLASH_FILE"
  verify_project_file_relocation "${WORK_DIR}/subscription.sing-box.json" "$SUB_SING_BOX_FILE"
  verify_project_file_relocation "${WORK_DIR}/subscription.auto.svg" "$SUB_AUTO_QR_FILE"

  [[ -e "${CONFIG_DIR}/argo-singbox.env" || -e "${WORK_DIR}/argo-singbox.env" || -e "${WORK_DIR}/nodes.conf" ||
    -e "${WORK_DIR}/sing-box.json" ||
    -e "${WORK_DIR}/nodes.txt" || -e "${WORK_DIR}/subscription.txt" ||
    -e "${WORK_DIR}/subscription.base64" || -e "${WORK_DIR}/subscription.clash.yaml" ||
    -e "${WORK_DIR}/subscription.sing-box.json" || -e "${WORK_DIR}/subscription.auto.svg" ]] || return 0

  ensure_project_layout
  relocate_project_file "${CONFIG_DIR}/argo-singbox.env" "$ENV_FILE" 600
  relocate_project_file "${WORK_DIR}/argo-singbox.env" "$ENV_FILE" 600
  relocate_project_file "${WORK_DIR}/nodes.conf" "$NODES_CONFIG" 600
  relocate_project_file "${WORK_DIR}/sing-box.json" "$SING_BOX_CONFIG" 600
  relocate_project_file "${WORK_DIR}/nodes.txt" "$NODES_FILE" 600
  relocate_project_file "${WORK_DIR}/subscription.txt" "$SUB_FILE" 644
  relocate_project_file "${WORK_DIR}/subscription.base64" "$SUB_BASE64_FILE" 644
  relocate_project_file "${WORK_DIR}/subscription.clash.yaml" "$SUB_CLASH_FILE" 644
  relocate_project_file "${WORK_DIR}/subscription.sing-box.json" "$SUB_SING_BOX_FILE" 644
  relocate_project_file "${WORK_DIR}/subscription.auto.svg" "$SUB_AUTO_QR_FILE" 644
  moved=1
  ((moved)) && green "已将现有配置、节点和订阅文件迁入分类目录。"
}

save_env() {
  local old_umask temp
  old_umask="$(umask)"
  ensure_project_layout
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
    printf 'STATS_API_PORT=%q\n' "$STATS_API_PORT"
    printf 'BRUTAL_UP_MBPS=%q\n' "$BRUTAL_UP_MBPS"
    printf 'BRUTAL_DOWN_MBPS=%q\n' "$BRUTAL_DOWN_MBPS"
  } >"$temp"
  chmod 600 "$temp"
  mv -f "$temp" "$ENV_FILE"
  umask "$old_umask"
}

valid_uuid() { [[ "${1,,}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; }
valid_path() { [[ "$1" =~ ^/[A-Za-z0-9._~-]+$ ]]; }
valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535)); }
valid_bandwidth_mbps() { [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 1 && 10#$1 <= 100000)); }
valid_argo_token() { [[ "$1" =~ ^[A-Za-z0-9._~+/=-]+$ ]]; }
valid_domain() { [[ "$1" =~ ^([A-Za-z0-9-]+\.)*[A-Za-z0-9-]+$ ]]; }
valid_core() { [[ "$1" == "sing-box" ]]; }

core_label() { printf 'Sing-box'; }

core_binary() { printf '%s/sing-box\n' "$BIN_DIR"; }

core_config() { printf '%s\n' "$SING_BOX_CONFIG"; }

tcp_brutal_system_name() { uname -s; }
tcp_brutal_kernel_release() { uname -r; }
tcp_brutal_modules_directory_exists() { [[ -d "/lib/modules/$1" ]]; }
tcp_brutal_headers_directory_exists() { [[ -d "/lib/modules/$1/build" ]]; }
tcp_brutal_apt_available() {
  command -v apt-get >/dev/null 2>&1 && command -v apt-cache >/dev/null 2>&1
}
tcp_brutal_package_installable() {
  local package="$1" candidate
  if command -v dpkg-query >/dev/null 2>&1 &&
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q '^install ok installed$'; then
    return 0
  fi
  candidate="$(LC_ALL=C apt-cache policy "$package" 2>/dev/null |
    awk '$1 == "Candidate:" {print $2; exit}')"
  [[ -n "$candidate" && "$candidate" != "(none)" ]]
}
tcp_brutal_dkms_available() {
  command -v dkms >/dev/null 2>&1 || tcp_brutal_package_installable dkms
}

tcp_brutal_container_detected() {
  if command -v systemd-detect-virt >/dev/null 2>&1 &&
    systemd-detect-virt --container >/dev/null 2>&1; then
    return 0
  fi
  [[ -e /proc/vz ]] && return 0
  grep -qaE '(docker|lxc|containerd|kubepods|openvz)' /proc/1/cgroup 2>/dev/null
}

tcp_brutal_kernel_modules_enabled() {
  local release="$1" config_file
  for config_file in "/boot/config-${release}" /proc/config.gz; do
    [[ -r "$config_file" ]] || continue
    if [[ "$config_file" == *.gz ]]; then
      command -v zgrep >/dev/null 2>&1 || continue
      zgrep -q '^# CONFIG_MODULES is not set' "$config_file" && return 1
      zgrep -q '^CONFIG_MODULES=y' "$config_file" && return 0
    else
      grep -q '^# CONFIG_MODULES is not set' "$config_file" && return 1
      grep -q '^CONFIG_MODULES=y' "$config_file" && return 0
    fi
  done
  return 0
}

tcp_brutal_kernel_at_least() {
  local release="${1%%-*}" required_major="$2" required_minor="$3"
  local major minor _
  IFS='.' read -r major minor _ <<<"$release"
  [[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] || return 1
  ((10#$major > required_major || (10#$major == required_major && 10#$minor >= required_minor)))
}

tcp_brutal_preflight() {
  local system release headers_package
  TCP_BRUTAL_SUPPORT_ERROR=""
  TCP_BRUTAL_SUPPORT_WARNING=""
  TCP_BRUTAL_HEADERS_STATE=""
  TCP_BRUTAL_HEADERS_PACKAGE=""
  system="$(tcp_brutal_system_name 2>/dev/null || true)"
  release="$(tcp_brutal_kernel_release 2>/dev/null || true)"
  TCP_BRUTAL_CHECKED_KERNEL="$release"
  if [[ "$system" != "Linux" ]]; then
    TCP_BRUTAL_SUPPORT_ERROR="TCP Brutal 仅支持 Linux。"
    return 1
  fi
  if [[ -z "$release" || "${release,,}" == *microsoft* ]]; then
    TCP_BRUTAL_SUPPORT_ERROR="当前内核不支持加载 TCP Brutal 模块。"
    return 1
  fi
  if ! tcp_brutal_kernel_at_least "$release" 4 9; then
    TCP_BRUTAL_SUPPORT_ERROR="当前内核 ${release} 低于官方最低要求 4.9。"
    return 1
  fi
  if tcp_brutal_container_detected; then
    TCP_BRUTAL_SUPPORT_ERROR="当前环境是容器，不能安全安装宿主机内核模块。"
    return 1
  fi
  if ! tcp_brutal_modules_directory_exists "$release"; then
    TCP_BRUTAL_SUPPORT_ERROR="当前内核缺少 /lib/modules/${release}，无法构建 DKMS 模块。"
    return 1
  fi
  if ! tcp_brutal_kernel_modules_enabled "$release"; then
    TCP_BRUTAL_SUPPORT_ERROR="当前内核未启用可加载模块（CONFIG_MODULES）。"
    return 1
  fi
  if ! tcp_brutal_apt_available; then
    TCP_BRUTAL_SUPPORT_ERROR="AGS 仅支持通过 Debian/Ubuntu APT 安装 TCP Brutal 官方依赖。"
    return 1
  fi
  if ! tcp_brutal_dkms_available; then
    TCP_BRUTAL_SUPPORT_ERROR="APT 中没有可安装的 dkms，无法使用 TCP Brutal 官方 DKMS 安装器。"
    return 1
  fi
  if tcp_brutal_headers_directory_exists "$release"; then
    TCP_BRUTAL_HEADERS_STATE="已安装"
  else
    headers_package="linux-headers-${release}"
    TCP_BRUTAL_HEADERS_PACKAGE="$headers_package"
    if ! tcp_brutal_package_installable "$headers_package"; then
      TCP_BRUTAL_SUPPORT_ERROR="当前运行内核 ${release} 缺少匹配头文件，且 APT 中没有可安装的 ${headers_package}。请先更新 APT；若仍不可用，请升级内核及匹配头文件并重启，再重新安装；不能使用其他版本头文件替代。"
      return 1
    fi
    TCP_BRUTAL_HEADERS_STATE="可安装 · ${headers_package}"
  fi
  if ! tcp_brutal_kernel_at_least "$release" 4 13; then
    TCP_BRUTAL_SUPPORT_WARNING="内核低于 4.13，安装后还需按官方说明为公网接口启用 fq pacing；低于 5.8 时仅支持 IPv4。"
  elif ! tcp_brutal_kernel_at_least "$release" 5 8; then
    TCP_BRUTAL_SUPPORT_WARNING="内核低于 5.8，TCP Brutal 仅支持 IPv4。"
  fi
  return 0
}

detect_tcp_brutal() {
  IS_BRUTAL=false
  if command -v lsmod >/dev/null 2>&1 && lsmod 2>/dev/null | awk '$1 == "brutal" { found=1 } END { exit !found }'; then
    IS_BRUTAL=true
    return 0
  fi
  if command -v lsmod >/dev/null 2>&1 && command -v modprobe >/dev/null 2>&1 &&
    modprobe brutal >/dev/null 2>&1 &&
    lsmod 2>/dev/null | awk '$1 == "brutal" { found=1 } END { exit !found }'; then
    IS_BRUTAL=true
  fi
}

tcp_brutal_status() {
  detect_tcp_brutal
  if [[ "$IS_BRUTAL" == "true" ]]; then
    printf '已启用 · %s/%s Mbps' "$BRUTAL_UP_MBPS" "$BRUTAL_DOWN_MBPS"
  else
    printf '未启用 · 缺少 brutal 内核模块'
  fi
}

validate_environment() {
  valid_core "$CORE" || die "核心类型无效。"
  valid_uuid "$UUID" || die "UUID 格式不正确。"
  valid_argo_token "$ARGO_TOKEN" || die "Argo Token 格式不正确。"
  valid_domain "$ARGO_DOMAIN" || die "Argo 域名格式不正确。"
  [[ "$SERVER" =~ ^[A-Za-z0-9._:-]+$ ]] || die "优选入口格式不正确。"
  valid_port "$SERVER_PORT" || die "优选入口端口无效。"
  valid_port "$ORIGIN_PORT" || die "Argo 回源端口无效。"
  valid_port "$STATS_API_PORT" || die "流量统计 API 端口无效。"
  valid_bandwidth_mbps "$BRUTAL_UP_MBPS" || die "TCP Brutal 上传带宽无效。"
  valid_bandwidth_mbps "$BRUTAL_DOWN_MBPS" || die "TCP Brutal 下载带宽无效。"
  ((10#$STATS_API_PORT != 10#$ORIGIN_PORT)) || die "流量统计 API 端口不能与 Argo 回源端口相同。"
  if [[ "$WARP_ENABLED" == "1" ]]; then
    valid_port "$WARP_PROXY_PORT" || die "WARP 本地代理端口无效。"
    ((10#$WARP_PROXY_PORT != 10#$STATS_API_PORT)) || die "WARP 代理端口不能与流量统计 API 端口相同。"
    normalize_warp_domains "$WARP_DOMAINS" >/dev/null
  fi
}

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

valid_socks5() {
  local value="$1" host port username password extra
  IFS=':' read -r host port username password extra <<<"$value"
  [[ -n "$host" && -n "$username" && -n "$password" && -z "${extra:-}" ]] || return 1
  [[ "$host" =~ ^[A-Za-z0-9.-]+$ ]] || return 1
  valid_port "$port" || return 1
  [[ "$username" =~ ^[A-Za-z0-9._~-]+$ && "$password" =~ ^[A-Za-z0-9._~-]+$ ]]
}

node_outbound_value() {
  local socks="$1" host port _
  [[ -n "$socks" ]] || {
    printf 'direct'
    return 0
  }
  IFS=':' read -r host port _ <<<"$socks"
  printf '%s:%s' "$host" "$port"
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
    case "$protocol" in
      vless|vmess|trojan) ;;
      *) die "不支持的节点协议：${protocol}" ;;
    esac
    valid_path "$path" || die "传输路径格式错误：${path}"
    valid_port "$port" || die "节点端口错误：${port}"
    ((10#$port != 10#$STATS_API_PORT)) || die "节点端口与流量统计 API 端口冲突：${port}"
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
    "https://github-proxy.fiatnorm.pp.ua/${url}" \
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
  die "下载失败（已尝试直连和 GitHub 反代）：${url}"
}

fetch_latest_installer() {
  local target="$1" checksum expected attempt
  checksum="$(mktemp)"
  for attempt in {1..3}; do
    download "https://raw.githubusercontent.com/${PROJECT_REPO}/${PROJECT_BRANCH}/ags.sh.sha256" "$checksum"
    download "https://raw.githubusercontent.com/${PROJECT_REPO}/${PROJECT_BRANCH}/ags.sh" "$target"
    expected="$(awk '$2 == "ags.sh" || $2 == "*ags.sh" {print $1; exit}' "$checksum")"
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
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates nginx openssl tar unzip qrencode jq sqlite3 util-linux
}

install_cloudflare_warp() {
  local answer codename key_file fingerprint
  command -v warp-cli >/dev/null 2>&1 && return
  read_input "确认安装 Cloudflare WARP 客户端？[Y/n]：" answer
  is_confirmed "$answer" || die "已取消安装 Cloudflare WARP 客户端。"
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
    read_input "确认删除并重新注册旧 WARP 注册？[Y/n]：" answer
    is_confirmed "$answer" ||
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

verify_github_asset() {
  local file="$1" repo="$2" release="$3" asset_name="$4" metadata expected
  metadata="$(mktemp)"
  download "https://api.github.com/repos/${repo}/releases/${release}" "$metadata"
  expected="$(awk -v wanted="$asset_name" '
    { payload = payload $0 }
    END {
      name_pattern = "\"name\"[[:space:]]*:[[:space:]]*\"" wanted "\""
      if (!match(payload, name_pattern)) exit
      remainder = substr(payload, RSTART + RLENGTH)
      if (!match(remainder, /"digest"[[:space:]]*:[[:space:]]*"sha256:[^"]+"/)) exit
      digest = substr(remainder, RSTART, RLENGTH)
      sub(/^.*sha256:/, "", digest)
      sub(/".*$/, "", digest)
      print digest
    }' "$metadata")"
  rm -f "$metadata"
  [[ "$expected" =~ ^[a-fA-F0-9]{64}$ ]] || die "GitHub 未提供 ${asset_name} 的 SHA256，拒绝安装。"
  printf '%s  %s\n' "$expected" "$file" | sha256sum -c - >/dev/null ||
    die "${asset_name} SHA256 校验失败。"
}

get_sing_box_version() {
  printf '%s\n' "$DEFAULT_SING_BOX_VERSION"
}


get_cloudflared_version() {
  printf '%s\n' "$DEFAULT_CLOUDFLARED_VERSION"
}

stage_sing_box() {
  local version="${1:-}" target="$2" archive temp_dir version_output asset_name archive_root
  [[ -n "$version" ]] || version="$(get_sing_box_version)"
  [[ -n "$version" ]] || die "无法确定 sing-box 版本。"
  asset_name="sing-box-${version}-linux-${ARCH}.tar.gz"
  archive_root="sing-box-${version}-linux-${ARCH}"
  archive="$(mktemp --suffix=.tar.gz)"
  download "https://github.com/${SING_BOX_REPO}/releases/download/v${version}/${asset_name}" "$archive"
  verify_github_asset "$archive" "$SING_BOX_REPO" "tags/v${version}" "$asset_name"
  temp_dir="$(mktemp -d)"
  tar -xzf "$archive" -C "$temp_dir"
  [[ -x "$temp_dir/${archive_root}/sing-box" ]] || die "官方 Sing-box 发布包结构无效。"
  install -m 755 "$temp_dir/${archive_root}/sing-box" "$target"
  version_output="$("$target" version 2>&1)"
  grep -Fq "sing-box version ${version}" <<<"$version_output" ||
    die "官方 Sing-box 版本校验失败。"
  grep -Fq "with_clash_api" <<<"$version_output" ||
    die "官方 Sing-box 发布包缺少 Clash API 构建标签。"
  rm -rf "$archive" "$temp_dir"
}

stage_cloudflared() {
  local version="${1:-}" target="$2" suffix
  [[ -n "$version" ]] || version="$(get_cloudflared_version)"
  [[ -n "$version" ]] || die "无法确定 cloudflared 版本。"
  [[ "$ARCH" == "amd64" ]] && suffix="amd64" || suffix="arm64"
  download "https://github.com/cloudflare/cloudflared/releases/download/${version}/cloudflared-linux-${suffix}" "$target"
  verify_github_asset "$target" "cloudflare/cloudflared" "tags/${version}" "cloudflared-linux-${suffix}"
  chmod 755 "$target"
  "$target" --version >/dev/null
}

local_sing_box_version() {
  "$BIN_DIR/sing-box" version 2>/dev/null | awk '/version/{sub(/^v/, "", $NF); print $NF; exit}'
}


local_core_version() { local_sing_box_version; }

get_core_version() { get_sing_box_version; }

stage_core() { stage_sing_box "$1" "$2"; }


sing_box_check() {
  local binary="${1:-${BIN_DIR}/sing-box}" config="${2:-$SING_BOX_CONFIG}"
  "$binary" check -c "$config"
}


core_check() { sing_box_check "${1:-${BIN_DIR}/sing-box}" "${2:-$SING_BOX_CONFIG}"; }

local_cloudflared_version() {
  "$BIN_DIR/cloudflared" --version 2>/dev/null |
    awk '{for (i=1; i<=NF; i++) if ($i=="version") {print $(i+1); exit}}'
}

write_sing_box_config() (
  local config_target="${1:-$SING_BOX_CONFIG}" check_binary="${2:-${BIN_DIR}/sing-box}"
  local tag protocol path port socks first=1 values host proxy_port username password
  SING_BOX_CONFIG="$config_target"
  ensure_project_layout
  ensure_nodes_config
  validate_environment
  validate_nodes_config
  detect_tcp_brutal
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
    printf '"multiplex":{"enabled":true,"padding":true,"brutal":{"enabled":%s,"up_mbps":%s,"down_mbps":%s}}}' \
      "$IS_BRUTAL" "$BRUTAL_UP_MBPS" "$BRUTAL_DOWN_MBPS" >>"$SING_BOX_CONFIG"
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
  printf '],"experimental":{"clash_api":{"external_controller":"127.0.0.1:%s"}},"route":{"rules":[' \
    "$STATS_API_PORT" >>"$SING_BOX_CONFIG"; first=1
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
  sing_box_check "$check_binary" "$SING_BOX_CONFIG"
)


write_all_core_configs() {
  [[ -x "${BIN_DIR}/sing-box" ]] || die "Sing-box 核心不存在。"
  write_sing_box_config
}

write_available_core_configs() { write_all_core_configs; }

write_nginx_config() {
  local tag protocol path port socks
  ensure_nodes_config
  validate_environment
  validate_nodes_config
  cat >"$NGINX_CONFIG" <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

map \$http_user_agent \$ags_subscription_file {
    default ${SUB_BASE64_FILE};
    ~*karing ${SUB_BASE64_FILE};
    ~*(clash|mihomo|stash) ${SUB_CLASH_FILE};
    ~*(sing-box|singbox|sfi|sfa|sfm) ${SUB_SING_BOX_FILE};
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
        proxy_buffering off;
        proxy_read_timeout 1h;
        proxy_send_timeout 1h;
    }
EOF
  done <"$NODES_CONFIG"
  cat >>"$NGINX_CONFIG" <<EOF
    location = /${UUID} {
        return 302 /${UUID}/;
    }
    location = /${UUID}/ {
        default_type text/html;
        return 200 '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>AGS 订阅中心</title><style>body{margin:0;background:#fff;color:#17345f;font:16px/1.65 system-ui,sans-serif}main{max-width:960px;margin:auto;padding:52px 24px 64px}.ey{margin:0;color:#0969da;font-size:12px;font-weight:800;letter-spacing:.14em}h1{margin:4px 0 5px;color:#0757c7;font-size:36px;letter-spacing:-.03em}p,small{color:#61708a}.hero,.card{border:1px solid #cfe1fb;border-radius:16px;background:#fff;box-shadow:0 10px 28px #1d5fa00d}.hero{display:grid;grid-template-columns:166px 1fr;gap:28px;align-items:center;margin:28px 0 40px;padding:26px}.hero img{display:block;width:146px;height:146px;padding:9px;border:1px solid #cfe1fb;border-radius:11px}.hero b{color:#0757c7;font-size:23px}.hero p{margin:6px 0 0}.open{display:inline-block;margin-top:16px;padding:9px 15px;border-radius:8px;background:#0969da;color:#fff;text-decoration:none;font-weight:800}.head{display:flex;justify-content:space-between;align-items:baseline;margin-bottom:14px}.head h2{margin:0;color:#0757c7;font-size:21px}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}.card{min-height:70px;padding:20px;color:#0757c7;text-decoration:none;font-weight:800;transition:border-color .16s,transform .16s,box-shadow .16s}.card:hover{border-color:#0969da;box-shadow:0 12px 28px #1d5fa018;transform:translateY(-2px)}.card small{display:block;margin-top:7px;font-weight:400}@media(max-width:560px){main{padding:34px 18px 48px}.hero{grid-template-columns:1fr;gap:18px;padding:22px}.hero img{margin:auto}.head{align-items:flex-start;flex-direction:column;gap:2px}.grid{grid-template-columns:1fr}}</style><main><p class=ey>AGS</p><h1>订阅中心</h1><p>选择适合客户端的订阅方式。</p><section class=hero><a href=auto><img src=auto-qr.svg alt="自适应订阅 QR"></a><div><b>自适应订阅</b><p>推荐使用。扫码或打开链接，自动匹配客户端格式。</p><a class=open href=auto>打开自适应订阅</a></div></section><div class=head><h2>指定格式</h2><small>共四类订阅</small></div><section class=grid><a class=card href=raw>原始节点订阅<small>VLESS、VMess、Trojan</small></a><a class=card href=base64>Base64 订阅<small>Karing、V2rayN、NekoBox</small></a><a class=card href=clash>Clash/Mihomo 订阅<small>完整 YAML 配置</small></a><a class=card href=sing-box>Sing-box 订阅<small>JSON 出站配置</small></a></section></main>';
    }
    location = /${UUID}/auto-qr.svg {
        default_type image/svg+xml;
        alias ${SUB_AUTO_QR_FILE};
    }
    location = /${UUID}/auto {
        default_type text/plain;
        alias \$ags_subscription_file;
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
    location = /${UUID}/sing-box {
        default_type application/json;
        alias ${SUB_SING_BOX_FILE};
    }
    location = /ags-sub {
        default_type text/plain;
        alias ${SUB_FILE};
    }
    location = /ags-sub-base64 {
        default_type text/plain;
        alias ${SUB_BASE64_FILE};
    }
    location / { return 404; }
}
EOF
  if ! LC_ALL=C awk '
    /return 200 / { found=1; if (length($0) >= 3500) invalid=1 }
    END { exit !(found && !invalid) }
  ' "$NGINX_CONFIG"; then
    die "订阅中心页面过长，拒绝写入可能导致 Nginx 配置失败的 return 指令。"
  fi
  nginx -t
}

write_services() {
  local binary config label
  binary="$(core_binary)"
  config="$(core_config)"
  label="$(core_label)"
  cat >"/etc/systemd/system/${CORE_SERVICE}.service" <<EOF
[Unit]
Description=AGS ${label} core
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${WORK_DIR}
ExecStart=${binary} run -c ${config}
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=-${LOCAL_SCRIPT} --traffic-collect
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
  chmod 600 "/etc/systemd/system/${CORE_SERVICE}.service"

  cat >"/etc/systemd/system/${ARGO_SERVICE}.service" <<EOF
[Unit]
Description=AGS Cloudflare 固定隧道
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

  cat >"/etc/systemd/system/${TRAFFIC_SERVICE}.service" <<EOF
[Unit]
Description=AGS 流量统计采集
After=${CORE_SERVICE}.service

[Service]
Type=oneshot
User=root
ExecStart=-${LOCAL_SCRIPT} --traffic-collect
NoNewPrivileges=true
EOF
  chmod 600 "/etc/systemd/system/${TRAFFIC_SERVICE}.service"

  cat >"/etc/systemd/system/${TRAFFIC_TIMER}.timer" <<EOF
[Unit]
Description=AGS 流量统计定时器

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min
AccuracySec=10s
Persistent=true
Unit=${TRAFFIC_SERVICE}.service

[Install]
WantedBy=timers.target
EOF
  chmod 600 "/etc/systemd/system/${TRAFFIC_TIMER}.timer"
}

ensure_traffic_database() {
  local table escaped_table
  command -v sqlite3 >/dev/null 2>&1 || return 1
  ensure_project_layout
  sqlite3 "$TRAFFIC_DB" >/dev/null <<'SQL'
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS global_totals (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  uplink INTEGER NOT NULL DEFAULT 0 CHECK (uplink >= 0),
  downlink INTEGER NOT NULL DEFAULT 0 CHECK (downlink >= 0),
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS global_baseline (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  process_token TEXT NOT NULL,
  upload_total INTEGER NOT NULL CHECK (upload_total >= 0),
  download_total INTEGER NOT NULL CHECK (download_total >= 0),
  updated_at TEXT NOT NULL
);
INSERT INTO meta(key, value) VALUES('started_at', datetime('now', 'localtime'))
  ON CONFLICT(key) DO NOTHING;
SQL
  while IFS= read -r table; do
    table="${table%$'\r'}"
    [[ -n "$table" ]] || continue
    escaped_table="${table//\"/\"\"}"
    sqlite3 "$TRAFFIC_DB" "DROP TABLE IF EXISTS \"${escaped_table}\";"
  done < <(sqlite3 "$TRAFFIC_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name NOT IN ('meta','global_totals','global_baseline');")
  sqlite3 "$TRAFFIC_DB" "DELETE FROM meta WHERE key NOT IN ('started_at','last_collect_at','reset_at');"
  chmod 600 "$TRAFFIC_DB"
}

traffic_collect() (
  local pid start_time process_token stats_json actual_binary api_address
  local candidate query_output upload_total download_total baseline baseline_token baseline_up baseline_down
  local delta_up delta_down seen_candidates=""
  load_env
  traffic_collect_fail() {
    printf '%s\n' "$1" >"$TRAFFIC_ERROR_FILE" 2>/dev/null || true
    chmod 600 "$TRAFFIC_ERROR_FILE" 2>/dev/null || true
    exit 1
  }
  valid_port "$STATS_API_PORT" || traffic_collect_fail "统计 API 端口无效。"
  command -v jq >/dev/null 2>&1 || traffic_collect_fail "系统缺少 jq。"
  command -v curl >/dev/null 2>&1 || traffic_collect_fail "系统缺少 curl。"
  ensure_traffic_database || traffic_collect_fail "无法初始化 SQLite 流量账本。"
  exec 9>"${DATA_DIR}/traffic.lock"
  flock -w 10 9 || traffic_collect_fail "流量账本正忙。"
  chmod 600 "${DATA_DIR}/traffic.lock"

  pid="$(systemctl show "$CORE_SERVICE" -p MainPID --value 2>/dev/null || true)"
  [[ "$pid" =~ ^[1-9][0-9]*$ && -r "/proc/${pid}/stat" ]] ||
    traffic_collect_fail "代理核心未运行或无法读取进程信息。"
  actual_binary="$(readlink -f "/proc/${pid}/exe" 2>/dev/null || true)"
  actual_binary="${actual_binary% (deleted)}"
  [[ "${actual_binary##*/}" == "sing-box" ]] || traffic_collect_fail "当前运行进程不是 Sing-box。"
  start_time="$(awk '{print $22}' "/proc/${pid}/stat" 2>/dev/null || true)"
  [[ "$start_time" =~ ^[0-9]+$ ]] || traffic_collect_fail "无法读取代理核心启动标识。"
  process_token="${pid}:${start_time}"

  api_address="$(jq -r '.experimental.clash_api.external_controller // empty' "$SING_BOX_CONFIG" 2>/dev/null || true)"
  stats_json=""
  while IFS= read -r candidate; do
    [[ "$candidate" =~ ^127\.0\.0\.1:[1-9][0-9]*$ ]] || continue
    [[ "$seen_candidates" == *"|${candidate}|"* ]] && continue
    seen_candidates+="|${candidate}|"
    if query_output="$(curl -fsS --connect-timeout 2 --max-time 10 "http://${candidate}/connections" 2>/dev/null)" &&
      jq -e '(.uploadTotal | type) == "number" and .uploadTotal >= 0 and
        (.downloadTotal | type) == "number" and .downloadTotal >= 0' >/dev/null 2>&1 <<<"$query_output"; then
      stats_json="$query_output"
      break
    fi
  done < <(
    printf '%s\n' "$api_address" "127.0.0.1:${STATS_API_PORT}"
  )
  [[ -n "$stats_json" ]] || traffic_collect_fail "Clash API 无响应，请检查当前核心配置与监听端口。"
  read -r upload_total download_total < <(jq -r '[.uploadTotal, .downloadTotal] | @tsv' <<<"$stats_json")
  [[ "$upload_total" =~ ^[0-9]+$ && "$download_total" =~ ^[0-9]+$ ]] ||
    traffic_collect_fail "Clash API 返回了无法解析的全局计数。"

  baseline="$(sqlite3 -separator '|' "$TRAFFIC_DB" \
    "SELECT process_token,upload_total,download_total FROM global_baseline WHERE id=1;")"
  delta_up="$upload_total"; delta_down="$download_total"
  if [[ -n "$baseline" ]]; then
    IFS='|' read -r baseline_token baseline_up baseline_down <<<"$baseline"
    if [[ "$baseline_token" == "$process_token" && "$baseline_up" =~ ^[0-9]+$ &&
      "$baseline_down" =~ ^[0-9]+$ && 10#$upload_total -ge 10#$baseline_up &&
      10#$download_total -ge 10#$baseline_down ]]; then
      delta_up="$((10#$upload_total - 10#$baseline_up))"
      delta_down="$((10#$download_total - 10#$baseline_down))"
    fi
  fi

  sqlite3 -batch "$TRAFFIC_DB" >/dev/null <<SQL || traffic_collect_fail "写入 SQLite 流量账本失败。"
BEGIN IMMEDIATE;
INSERT INTO global_totals(id, uplink, downlink, updated_at)
VALUES(1, ${delta_up}, ${delta_down}, datetime('now', 'localtime'))
ON CONFLICT(id) DO UPDATE SET
  uplink = global_totals.uplink + excluded.uplink,
  downlink = global_totals.downlink + excluded.downlink,
  updated_at = excluded.updated_at;
INSERT INTO global_baseline(id, process_token, upload_total, download_total, updated_at)
VALUES(1, '${process_token}', ${upload_total}, ${download_total}, datetime('now', 'localtime'))
ON CONFLICT(id) DO UPDATE SET
  process_token = excluded.process_token,
  upload_total = excluded.upload_total,
  download_total = excluded.download_total,
  updated_at = excluded.updated_at;
INSERT INTO meta(key, value) VALUES('last_collect_at', datetime('now', 'localtime'))
ON CONFLICT(key) DO UPDATE SET value = excluded.value;
COMMIT;
SQL
  rm -f "$TRAFFIC_ERROR_FILE"
)

ensure_traffic_timer_running() {
  systemctl is-active --quiet "${TRAFFIC_TIMER}.timer" && return 0
  [[ -f "/etc/systemd/system/${TRAFFIC_SERVICE}.service" &&
    -f "/etc/systemd/system/${TRAFFIC_TIMER}.timer" ]] || return 1
  systemctl daemon-reload >/dev/null 2>&1 &&
    systemctl enable --now "${TRAFFIC_TIMER}.timer" >/dev/null 2>&1
}

traffic_reset() (
  local clear_baselines=0
  if systemctl is-active --quiet "$CORE_SERVICE"; then
    traffic_collect || die "当前核心的统计计数读取失败，未重置历史数据。"
  else
    clear_baselines=1
  fi
  ensure_traffic_database || die "缺少 SQLite，无法重置流量统计。"
  exec 9>"${DATA_DIR}/traffic.lock"
  flock -w 10 9 || die "流量数据库正忙，请稍后重试。"
  if ((clear_baselines)); then
    sqlite3 "$TRAFFIC_DB" "BEGIN IMMEDIATE; DELETE FROM global_totals; DELETE FROM global_baseline; INSERT INTO meta(key,value) VALUES('reset_at',datetime('now','localtime')) ON CONFLICT(key) DO UPDATE SET value=excluded.value; COMMIT;"
  else
    sqlite3 "$TRAFFIC_DB" "BEGIN IMMEDIATE; DELETE FROM global_totals; INSERT INTO meta(key,value) VALUES('reset_at',datetime('now','localtime')) ON CONFLICT(key) DO UPDATE SET value=excluded.value; COMMIT;"
  fi
)

format_traffic_bytes() {
  local bytes="${1:-0}" divisor unit whole decimal
  [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
  if ((bytes < 1024)); then printf '%s B' "$bytes"; return; fi
  if ((bytes < 1024 * 1024)); then divisor=1024; unit="KB"
  elif ((bytes < 1024 * 1024 * 1024)); then divisor=$((1024 * 1024)); unit="MB"
  elif ((bytes < 1024 * 1024 * 1024 * 1024)); then divisor=$((1024 * 1024 * 1024)); unit="GB"
  else divisor=$((1024 * 1024 * 1024 * 1024)); unit="TB"
  fi
  whole=$((bytes / divisor))
  decimal=$((((bytes % divisor) * 10 + divisor / 2) / divisor))
  ((decimal >= 10)) && { ((whole+=1)); decimal=0; }
  printf '%s.%s %s' "$whole" "$decimal" "$unit"
}

traffic_table_header() {
  printf '  %s' "$C_BRIGHT_CYAN"
  pad_right "范围" 14
  printf '%s  %s' "$C_RESET" "$C_BRIGHT_CYAN"
  pad_right "上传" 10
  printf '  '
  pad_right "下载" 10
  printf '  合计%s\n' "$C_RESET"
}

traffic_table_row() {
  local label up down total
  label="$(fit_text "$1" 14)"; up="$(format_traffic_bytes "$2")"
  down="$(format_traffic_bytes "$3")"; total="$(format_traffic_bytes "$(($2 + $3))")"
  printf '  %s%s%s  %s%10s  %10s  %10s%s\n' "$C_BRIGHT_MAGENTA" "$label" "$C_RESET" \
    "$C_BRIGHT_WHITE" "$up" "$down" "$total" "$C_RESET"
}

show_traffic_tables() {
  local values up down
  values="$(sqlite3 -separator '|' "$TRAFFIC_DB" \
    "SELECT uplink,downlink FROM global_totals WHERE id=1;")"
  [[ -n "$values" ]] || values="0|0"
  IFS='|' read -r up down <<<"$values"
  traffic_table_header
  traffic_table_row "全局流量" "$up" "$down"
}

traffic_statistics_menu() {
  local choice answer collected last_collect reset_at collect_error
  require_root
  [[ -f "$ENV_FILE" && -f "$NODES_CONFIG" ]] || die "${PROJECT_NAME} 尚未安装。"
  command -v sqlite3 >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 ||
    die "缺少 jq 或 sqlite3，请执行项目安装更新依赖。"
  ensure_traffic_timer_running || true
  while true; do
    load_env
    validate_nodes_config
    ensure_traffic_database || die "无法初始化流量数据库。"
    collected=1
    traffic_collect || collected=0
    last_collect="$(sqlite3 "$TRAFFIC_DB" "SELECT value FROM meta WHERE key='last_collect_at';")"
    reset_at="$(sqlite3 "$TRAFFIC_DB" "SELECT value FROM meta WHERE key='reset_at';")"
    [[ -n "$reset_at" ]] || reset_at="$(sqlite3 "$TRAFFIC_DB" "SELECT value FROM meta WHERE key='started_at';")"
    brand "${PROJECT_NAME} · 流量统计" back
    subsection "统计状态"
    state_value "定时采集" "$({ systemctl is-active --quiet "${TRAFFIC_TIMER}.timer" && printf '运行中'; } || printf '已停止') · 每分钟"
    key_value "统计起点" "${reset_at:-未知}"
    key_value "最近采集" "${last_collect:-尚未采集}"
    ((collected)) || yellow "当前核心计数暂不可读，以下显示已持久化数据。"
    if ((!collected)) && [[ -s "$TRAFFIC_ERROR_FILE" ]]; then
      collect_error="$(head -n 1 "$TRAFFIC_ERROR_FILE")"
      key_value "失败原因" "$collect_error"
    fi
    subsection "全局统计"
    show_traffic_tables
    section "统计操作"
    menu_item 1 "刷新统计"
    menu_item 2 "重置统计"
    menu_item 0 "返回上级"
    ui_line
    read_choice "请选择："; choice="$REPLY"
    case "$choice" in
      1) continue ;;
      2)
        read_input "确认清空全部历史流量？[Y/n]：" answer
        is_confirmed "$answer" || { yellow "已取消重置。"; continue; }
        traffic_reset
        green "流量统计已重置。"
        ;;
      0) return ;;
      *) yellow "请输入 0、1 或 2。" ;;
    esac
  done
}

generate_nodes() {
  local old_umask vmess_json vmess_link tag protocol path port socks encoded_path vmess_path first uri_server auto_url
  local clash_early_data clash_multiplex sing_box_early_data
  ensure_nodes_config
  validate_environment
  validate_nodes_config
  detect_tcp_brutal
  old_umask="$(umask)"
  umask 077
  uri_server="$SERVER"
  [[ "$uri_server" == *:* ]] && uri_server="[${uri_server}]"
  clash_early_data=', max-early-data: 2560, early-data-header-name: Sec-WebSocket-Protocol'
  clash_multiplex=", smux: {enabled: true, protocol: h2mux, max-streams: ${MULTIPLEX_MAX_STREAMS}, statistic: true, only-tcp: false, padding: true, brutal-opts: {enabled: ${IS_BRUTAL}, up: ${BRUTAL_UP_MBPS}, down: ${BRUTAL_DOWN_MBPS}}}"
  sing_box_early_data=',"max_early_data":2560,"early_data_header_name":"Sec-WebSocket-Protocol"'
  : >"$NODES_FILE"
  while IFS='|' read -r tag protocol path port socks; do
    encoded_path="%2F${path#/}"
    vmess_path="$path"
    case "$protocol" in
      vless) printf 'vless://%s@%s:%s?encryption=none&security=tls&sni=%s&fp=chrome&insecure=0&allowInsecure=0&type=ws&host=%s&path=%s&packetEncoding=xudp#%s\n' \
        "$UUID" "$uri_server" "$SERVER_PORT" "$ARGO_DOMAIN" "$ARGO_DOMAIN" "${encoded_path}%3Fed%3D2560" "$tag" >>"$NODES_FILE" ;;
      trojan) printf 'trojan://%s@%s:%s?security=tls&sni=%s&fp=chrome&insecure=0&allowInsecure=0&type=ws&host=%s&path=%s#%s\n' \
        "$UUID" "$uri_server" "$SERVER_PORT" "$ARGO_DOMAIN" "$ARGO_DOMAIN" "${encoded_path}%3Fed%3D2560" "$tag" >>"$NODES_FILE" ;;
      vmess)
        vmess_path+="?ed=2560"
        vmess_json="{\"v\":\"2\",\"ps\":\"${tag}\",\"add\":\"${SERVER}\",\"port\":\"${SERVER_PORT}\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"aes-128-gcm\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${ARGO_DOMAIN}\",\"path\":\"${vmess_path}\",\"tls\":\"tls\",\"sni\":\"${ARGO_DOMAIN}\",\"fp\":\"chrome\",\"alpn\":\"\",\"packetEncoding\":\"xudp\"}"
        vmess_link="$(printf '%s' "$vmess_json" | base64 -w 0)"
        printf 'vmess://%s\n' "$vmess_link" >>"$NODES_FILE" ;;
    esac
  done <"$NODES_CONFIG"
  chmod 600 "$NODES_FILE"
  install -m 644 "$NODES_FILE" "$SUB_FILE"
  base64 -w 0 "$NODES_FILE" >"$SUB_BASE64_FILE"
  auto_url="https://${ARGO_DOMAIN}/${UUID}/auto"
  qrencode -t SVG -o "$SUB_AUTO_QR_FILE" "$auto_url"
  printf 'proxies:\n' >"$SUB_CLASH_FILE"
  while IFS='|' read -r tag protocol path port socks; do
    case "$protocol" in
      vless) printf '  - {name: "%s", type: vless, server: "%s", port: %s, uuid: %s, encryption: none, udp: true, packet-encoding: xudp, tls: true, servername: %s, client-fingerprint: chrome, alpn: [http/1.1], skip-cert-verify: false, network: ws, ws-opts: {path: "%s", headers: {Host: %s}%s}%s}\n' \
        "$tag" "$SERVER" "$SERVER_PORT" "$UUID" "$ARGO_DOMAIN" "$path" "$ARGO_DOMAIN" "$clash_early_data" "$clash_multiplex" ;;
      vmess) printf '  - {name: "%s", type: vmess, server: "%s", port: %s, uuid: %s, alterId: 0, cipher: aes-128-gcm, udp: true, packet-encoding: xudp, tls: true, servername: %s, client-fingerprint: chrome, alpn: [http/1.1], skip-cert-verify: false, network: ws, ws-opts: {path: "%s", headers: {Host: %s}%s}%s}\n' \
        "$tag" "$SERVER" "$SERVER_PORT" "$UUID" "$ARGO_DOMAIN" "$path" "$ARGO_DOMAIN" "$clash_early_data" "$clash_multiplex" ;;
      trojan) printf '  - {name: "%s", type: trojan, server: "%s", port: %s, password: %s, udp: true, tls: true, sni: %s, client-fingerprint: chrome, alpn: [http/1.1], skip-cert-verify: false, network: ws, ws-opts: {path: "%s", headers: {Host: %s}%s}%s}\n' \
        "$tag" "$SERVER" "$SERVER_PORT" "$UUID" "$ARGO_DOMAIN" "$path" "$ARGO_DOMAIN" "$clash_early_data" "$clash_multiplex" ;;
    esac
  done <"$NODES_CONFIG" >>"$SUB_CLASH_FILE"
  printf 'proxy-groups:\n  - name: PROXY\n    type: select\n    proxies:\n' >>"$SUB_CLASH_FILE"
  while IFS='|' read -r tag protocol path port socks; do
    printf '      - "%s"\n' "$tag"
  done <"$NODES_CONFIG" >>"$SUB_CLASH_FILE"
  printf 'rules:\n  - MATCH,PROXY\n' >>"$SUB_CLASH_FILE"

  printf '{"outbounds":[' >"$SUB_SING_BOX_FILE"
  first=1
  while IFS='|' read -r tag protocol path port socks; do
    ((first)) || printf ',' >>"$SUB_SING_BOX_FILE"; first=0
    case "$protocol" in
      *)
        printf '{"type":"%s","tag":"%s","server":"%s","server_port":%s,' \
          "$protocol" "$tag" "$SERVER" "$SERVER_PORT" >>"$SUB_SING_BOX_FILE"
        case "$protocol" in
          trojan) printf '"password":"%s",' "$UUID" >>"$SUB_SING_BOX_FILE" ;;
          vmess) printf '"uuid":"%s","security":"aes-128-gcm","alter_id":0,"packet_encoding":"xudp",' "$UUID" >>"$SUB_SING_BOX_FILE" ;;
          vless) printf '"uuid":"%s","flow":"","packet_encoding":"xudp",' "$UUID" >>"$SUB_SING_BOX_FILE" ;;
        esac
        printf '"tls":{"enabled":true,"server_name":"%s","insecure":false,"utls":{"enabled":true,"fingerprint":"chrome"}},"transport":{"type":"ws","path":"%s","headers":{"Host":"%s"}%s},' \
          "$ARGO_DOMAIN" "$path" "$ARGO_DOMAIN" "$sing_box_early_data" >>"$SUB_SING_BOX_FILE"
        printf '"multiplex":{"enabled":true,"protocol":"h2mux","max_streams":%s,"padding":true,"brutal":{"enabled":%s,"up_mbps":%s,"down_mbps":%s}}}' \
          "$MULTIPLEX_MAX_STREAMS" "$IS_BRUTAL" "$BRUTAL_UP_MBPS" "$BRUTAL_DOWN_MBPS" >>"$SUB_SING_BOX_FILE"
        ;;
    esac
  done <"$NODES_CONFIG"
  printf ']}\n' >>"$SUB_SING_BOX_FILE"
  chmod 644 "$SUB_BASE64_FILE"
  chmod 644 "$SUB_CLASH_FILE" "$SUB_SING_BOX_FILE" \
    "$SUB_AUTO_QR_FILE"
  umask "$old_umask"
}

create_local_command() {
  local source_script="${1:-$0}" legacy_command legacy_path target
  install -m 755 "$source_script" "${LOCAL_SCRIPT}.new"
  mv -f "${LOCAL_SCRIPT}.new" "$LOCAL_SCRIPT"
  ln -sfn "$LOCAL_SCRIPT" "/usr/local/bin/${COMMAND_NAME}"
  ln -sfn "$LOCAL_SCRIPT" "/usr/local/bin/${COMMAND_NAME_UPPER}"
  for legacy_command in asb ASB; do
    legacy_path="/usr/local/bin/${legacy_command}"
    [[ -L "$legacy_path" ]] || continue
    target="$(readlink -f "$legacy_path" 2>/dev/null || true)"
    case "$target" in
      "$LOCAL_SCRIPT"|"${PREVIOUS_WORK_DIR}/argo-singbox.sh"|"${LEGACY_WORK_DIR}/argo-singbox.sh")
        rm -f "$legacy_path"
        ;;
    esac
  done
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
    generate_nodes
    systemctl reload nginx
  elif [[ -z "$actual_domain" ]]; then
    # 固定 Token 隧道的日志并不保证输出 Public Hostname；保留用户输入值即可。
    :
  fi
}

wait_for_services() {
  local attempt service ready
  local services=("$@")
  ((${#services[@]})) || services=(nginx "$CORE_SERVICE" "$ARGO_SERVICE")
  for attempt in {1..20}; do
    ready=1
    for service in "${services[@]}"; do
      systemctl is-active --quiet "$service" || ready=0
    done
    [[ "$ready" -eq 1 ]] && return 0
    sleep 1
  done
  return 1
}

report_runtime_config_failure() {
  local service
  for service in "$@"; do
    systemctl is-active --quiet "$service" && continue
    red "${service}：重启后未运行。"
    systemctl --no-pager --full status "$service" 2>&1 | filter_journal_noise || true
    journalctl -u "$service" -n 20 --no-pager -o cat 2>/dev/null |
      filter_journal_noise || true
  done
}

health_check() {
  local failed=0 public_code public_headers curl_status port path tag protocol socks mode="${1:-full}"
  ensure_nodes_config
  if [[ "$mode" == "ws" ]]; then
    section "传输检查"
  else
    section "运行检查"
    for service in nginx "$CORE_SERVICE" "$ARGO_SERVICE"; do
      if systemctl is-active --quiet "$service"; then
        green "$(service_label "$service") 运行正常。"
      else
        red "$(service_label "$service") 未运行。"
        systemctl --no-pager --full status "$service" 2>&1 | filter_journal_noise || true
        journalctl -u "$service" -n 20 --no-pager -o cat 2>/dev/null |
          filter_journal_noise || true
        failed=1
      fi
    done
    if systemctl is-active --quiet "${TRAFFIC_TIMER}.timer"; then
      green "流量统计定时器运行正常。"
    else
      red "流量统计定时器未运行。"
      failed=1
    fi
    if traffic_collect; then
      green "Clash API 全局流量统计已通过。"
    else
      red "Clash API 全局流量统计无效。"
      failed=1
    fi
  fi

  while read -r port; do
    if ! ss -lntH "sport = :${port}" 2>/dev/null | grep -q .; then
      red "本地端口 ${port} 未监听。"
      failed=1
    fi
  done < <(printf '%s\n' "$ORIGIN_PORT" "$STATS_API_PORT"; cut -d'|' -f4 "$NODES_CONFIG")

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
      green "${path}：公网 WS 握手正常"
    elif [[ "$curl_status" -eq 28 ]]; then
      yellow "${path}：公网传输探测超时，未视为安装失败；请用客户端实测。"
    else
      red "${path}：公网传输探测失败（HTTP ${public_code:-000}）"
      failed=1
    fi
  done <"$NODES_CONFIG"
  [[ "$failed" -eq 0 ]] || yellow "请确认 Public Hostname 指向 http://localhost:${ORIGIN_PORT}，并跳过全部代理路径的 Challenge/WAF。"

  return "$failed"
}

prompt_install_values() {
  local value endpoint page_mode="cancel"
  [[ -n "$ARGO_TOKEN$ARGO_DOMAIN" ]] && page_mode="default"
  brand "${PROJECT_NAME} · 安装配置" "$page_mode"
  subsection "配置输入"
  if [[ -n "$ARGO_TOKEN" ]]; then
    read_input "Argo Token [已配置]：" value
  else
    read_input "Argo Token [必填]：" value
  fi
  is_exit_input "$value" && return 1
  value="${value:-$ARGO_TOKEN}"
  valid_argo_token "$value" || die "Argo Token 格式不正确。"
  ARGO_TOKEN="$value"
  if [[ -n "$ARGO_DOMAIN" ]]; then
    read_input "Argo 域名 [${ARGO_DOMAIN}]：" value
  else
    read_input "Argo 域名 [必填]：" value
  fi
  is_exit_input "$value" && return 1
  ARGO_DOMAIN="${value:-$ARGO_DOMAIN}"
  [[ -n "$ARGO_DOMAIN" ]] || die "Argo 域名不能为空。"
  [[ -n "$UUID" ]] || UUID="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || true)"
  [[ -n "$UUID" ]] || UUID="$(openssl rand -hex 16 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\)$/\1-\2-\3-\4-\5/')"
  read_input "UUID [${UUID}]：" value
  is_exit_input "$value" && return 1
  UUID="${value:-$UUID}"
  [[ "${UUID,,}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]] ||
    die "UUID 格式不正确。"
  read_input "优选入口 [${SERVER}:${SERVER_PORT}]：" endpoint
  is_exit_input "$endpoint" && return 1
  endpoint="${endpoint:-${SERVER}:${SERVER_PORT}}"
  parse_endpoint "$endpoint"
  valid_domain "$ARGO_DOMAIN" || die "Argo 域名格式不正确。"
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
  for unit in "$CORE_SERVICE" "$ARGO_SERVICE"; do
    marker="/etc/systemd/system/${unit}.service"
    if [[ -e "$marker" ]] && ! grep -Eq "^Description=${PROJECT_NAME} " "$marker"; then
      die "检测到非本项目服务 ${unit}.service，安装已停止，未覆盖现有服务。"
    fi
  done
  for unit in sing-box cloudflared; do
    marker="/etc/systemd/system/${unit}.service"
    [[ -e "$marker" ]] || continue
    if grep -Eq '^Description=(AGS|Argo-Singbox) ' "$marker"; then
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
    grep -Eq '^Description=(AGS|Argo-Singbox) ' "$unit_file"
}

assert_command_names_available() {
  local command_path target command
  for command in "$COMMAND_NAME" "$COMMAND_NAME_UPPER"; do
    command_path="/usr/local/bin/${command}"
    [[ -e "$command_path" || -L "$command_path" ]] || continue
    [[ -L "$command_path" ]] ||
      die "检测到非项目命令 ${command_path}，拒绝覆盖。"
    target="$(readlink -f "$command_path" 2>/dev/null || true)"
    case "$target" in
      "$LOCAL_SCRIPT"|"${PREVIOUS_WORK_DIR}/argo-singbox.sh"|"${LEGACY_WORK_DIR}/argo-singbox.sh") ;;
      *) die "检测到未知命令链接 ${command_path}，拒绝覆盖。" ;;
    esac
  done
}

migrate_managed_work_dir() {
  local source_dir="$1" source_label="$2" source_target
  [[ -e "$source_dir" || -L "$source_dir" ]] || return 0
  if [[ -L "$source_dir" ]]; then
    source_target="$(readlink -f "$source_dir" 2>/dev/null || true)"
    if [[ "$source_target" == "$WORK_DIR" && -f "$MANAGED_FILE" ]]; then
      LEGACY_MIGRATED=1
      return 0
    fi
    die "检测到未知旧目录符号链接 ${source_dir}，拒绝自动迁移。"
  fi
  [[ -d "$source_dir" ]] || die "旧项目路径类型异常，拒绝自动迁移：${source_dir}"
  [[ -f "${source_dir}/managed" ]] ||
    die "检测到 ${source_dir} 但缺少项目所有权标记，拒绝自动迁移。"
  [[ ! -e "$WORK_DIR" ]] ||
    die "${WORK_DIR} 与旧目录 ${source_dir} 同时存在，请先人工核对，拒绝自动覆盖。"
  mv "$source_dir" "$WORK_DIR"
  ln -s "$WORK_DIR" "$source_dir"
  LEGACY_MIGRATED=1
  green "已将 ${source_label} 安装目录迁移为 ${WORK_DIR}。"
}

migrate_legacy_install() {
  local migration_backup legacy_file source_count=0 source_dir
  for source_dir in "$PREVIOUS_WORK_DIR" "$LEGACY_WORK_DIR"; do
    [[ -L "$source_dir" || ! -e "$source_dir" ]] || ((source_count += 1))
  done
  ((source_count <= 1)) ||
    die "检测到 ${PREVIOUS_WORK_DIR} 与 ${LEGACY_WORK_DIR} 两个旧安装目录，请先人工核对。"

  migrate_managed_work_dir "$PREVIOUS_WORK_DIR" "旧项目"
  migrate_managed_work_dir "$LEGACY_WORK_DIR" "旧项目"

  if ((LEGACY_MIGRATED == 0)) && [[ ! -f "${WORK_DIR}/asb.env" ]]; then
    return 0
  fi
  ensure_project_layout
  migration_backup="${BACKUP_DIR}/pre-ags-namespace"
  install -d -m 700 "$migration_backup"
  for legacy_file in asb.env argo-singbox.sh; do
    [[ -f "${WORK_DIR}/${legacy_file}" ]] && cp -a "${WORK_DIR}/${legacy_file}" "$migration_backup/"
  done
  if [[ -f "${CONFIG_DIR}/argo-singbox.env" ]]; then
    cp -a "${CONFIG_DIR}/argo-singbox.env" "$migration_backup/"
  fi
  [[ -f "$NODES_CONFIG" ]] && cp -a "$NODES_CONFIG" "$migration_backup/"
  if [[ -f "${WORK_DIR}/asb.env" ]]; then
    mv "${WORK_DIR}/asb.env" "$ENV_FILE"
  fi
}

remove_legacy_services() {
  local service unit_file
  for service in "$PREVIOUS_CORE_SERVICE" "$PREVIOUS_ARGO_SERVICE" \
    "$PREVIOUS_TRAFFIC_SERVICE" "$LEGACY_CORE_SERVICE" "$LEGACY_ARGO_SERVICE"; do
    unit_file="/etc/systemd/system/${service}.service"
    [[ -e "$unit_file" ]] || continue
    if is_project_service "$unit_file"; then
      systemctl disable --now "$service" 2>/dev/null || true
      rm -f "$unit_file"
    else
      yellow "保留非本项目旧服务：${service}.service"
    fi
  done
  unit_file="/etc/systemd/system/${PREVIOUS_TRAFFIC_TIMER}.timer"
  if [[ -e "$unit_file" ]]; then
    systemctl disable --now "${PREVIOUS_TRAFFIC_TIMER}.timer" 2>/dev/null || true
    rm -f "$unit_file"
  fi
}

remove_legacy_symlink() {
  local target source_dir
  for source_dir in "$PREVIOUS_WORK_DIR" "$LEGACY_WORK_DIR"; do
    [[ -L "$source_dir" ]] || continue
    target="$(readlink -f "$source_dir" 2>/dev/null || true)"
    [[ "$target" == "$WORK_DIR" ]] && rm -f "$source_dir"
  done
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
    [[ "$exec_start" == *"${WORK_DIR}/"* || "$exec_start" == *"${PREVIOUS_WORK_DIR}/"* ||
      "$exec_start" == *"${LEGACY_WORK_DIR}/"* ]]
}

stop_conflicting_core_services() {
  local service
  systemctl stop "$CORE_SERVICE" 2>/dev/null || true
  for service in "$PREVIOUS_CORE_SERVICE" "$LEGACY_CORE_SERVICE" sing-box; do
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
        "${BIN_DIR}/sing-box"|"${PREVIOUS_WORK_DIR}/bin/sing-box"|"${PREVIOUS_WORK_DIR}/sing-box"|"${LEGACY_WORK_DIR}/bin/sing-box"|"${LEGACY_WORK_DIR}/sing-box")
          kill "$pid" 2>/dev/null || true
          info "已停止遗留项目核心进程 PID ${pid}（端口 ${port}）。"
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
  section "原始节点"
  cat "$NODES_FILE"
  printf '\n'
}

install_project() {
  local install_mode="${1:-local}" installer_source latest_installer
  local work_backup="" core_stage argo_stage file
  require_root
  installer_source="$(mktemp)"
  install -m 755 "$0" "$installer_source"
  assert_command_names_available
  control_panel
  subsection "安装准备"
  menu_hint "输入 0 可取消本次安装。"
  if [[ "$install_mode" == "github" ]]; then
    latest_installer="$(mktemp)"
    info "正在获取最新安装脚本..."
    fetch_latest_installer "$latest_installer"
    if ! cmp -s "$latest_installer" "$0"; then
      migrate_legacy_install
      install -d -m 755 "$WORK_DIR"
      create_local_command "$latest_installer"
      rm -f "$latest_installer" "$installer_source"
      green "脚本已更新，正在使用新版继续安装。"
      exec bash "$LOCAL_SCRIPT" -i --github-refreshed
    fi
    rm -f "$latest_installer"
    green "当前脚本已是最新版本。"
  elif [[ "$install_mode" != "local" ]]; then
    die "未知安装模式：${install_mode}"
  fi
  migrate_legacy_install
  migrate_project_layout
  load_env
  if ! prompt_install_values; then
    yellow "已取消安装，未写入配置。"
    rm -f "$installer_source"
    return 0
  fi
  ensure_project_layout
  ensure_nodes_config
  validate_nodes_config
  detect_arch
  install_dependencies
  assert_service_names_available
  install -d -m 755 "$WORK_DIR" "$BIN_DIR"
  ensure_project_layout
  install -d -m 700 "$BACKUP_DIR"
  for file in "$ENV_FILE" "$NODES_CONFIG" "$SING_BOX_CONFIG" "$NGINX_CONFIG" \
    "$LEGACY_NGINX_CONFIG" "$OLDER_NGINX_CONFIG" "$LOCAL_SCRIPT"; do
    if [[ -f "$file" ]]; then
      if [[ -z "$work_backup" ]]; then
        work_backup="${BACKUP_DIR}/config-previous"
        rm -rf "$work_backup"
        install -d -m 700 "$work_backup"
      fi
      cp -a "$file" "$work_backup/"
    fi
  done
  core_stage="$(mktemp)"; argo_stage="$(mktemp)"
  stage_sing_box "$DEFAULT_SING_BOX_VERSION" "$core_stage"
  stage_cloudflared "$DEFAULT_CLOUDFLARED_VERSION" "$argo_stage"
  install -m 755 "$core_stage" "${BIN_DIR}/sing-box.new"
  install -m 755 "$argo_stage" "${BIN_DIR}/cloudflared.new"
  mv -f "${BIN_DIR}/sing-box.new" "${BIN_DIR}/sing-box"
  mv -f "${BIN_DIR}/cloudflared.new" "${BIN_DIR}/cloudflared"
  rm -f "$core_stage" "$argo_stage"
  printf 'project=%s\nversion=%s\n' "$PROJECT_CODE" "$VERSION" >"$MANAGED_FILE"
  save_env
  write_all_core_configs
  if [[ -f "$LEGACY_NGINX_CONFIG" ]] &&
    grep -q '/etc/argo-singbox/' "$LEGACY_NGINX_CONFIG"; then
    rm -f "$LEGACY_NGINX_CONFIG"
  fi
  if [[ -f "$OLDER_NGINX_CONFIG" ]] &&
    grep -q '/etc/asb/' "$OLDER_NGINX_CONFIG" &&
    grep -qE '(/asb-sub|/argo-vl|/argo-vm|/argo-tr)' "$OLDER_NGINX_CONFIG"; then
    rm -f "$OLDER_NGINX_CONFIG"
  fi
  write_nginx_config
  generate_nodes
  write_services
  create_local_command "$installer_source"
  rm -f "$installer_source"
  systemctl daemon-reload
  systemctl enable nginx "$CORE_SERVICE" "$ARGO_SERVICE" "${TRAFFIC_TIMER}.timer"
  stop_conflicting_core_services
  stop_orphan_project_listeners
  if ! wait_for_node_ports_free; then
    report_node_port_owners >&2
    die "节点端口仍被未知进程占用。为避免终止第三方服务，安装已停止。"
  fi
  systemctl restart nginx "$CORE_SERVICE" "$ARGO_SERVICE" "${TRAFFIC_TIMER}.timer"
  if wait_for_services; then
    : # 完整健康检查通过前，保留旧服务与目录兼容链接以便回退。
  else
    yellow "新服务尚未全部启动，已保留旧服务文件以便排查。"
    if ((LEGACY_MIGRATED)); then
      systemctl disable --now "${TRAFFIC_TIMER}.timer" "$CORE_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
      systemctl restart "$PREVIOUS_CORE_SERVICE" "$PREVIOUS_ARGO_SERVICE" \
        "$LEGACY_CORE_SERVICE" "$LEGACY_ARGO_SERVICE" 2>/dev/null || true
      yellow "已先停用新服务再恢复旧服务，避免新旧 sing-box 同时抢占节点端口。"
    fi
  fi
  systemctl daemon-reload
  sync_argo_domain
  rm -f "$LEGACY_NODES_FILE"
  if health_check; then
    remove_legacy_services
    rm -f "${WORK_DIR}/argo-singbox.sh" "${CONFIG_DIR}/argo-singbox.env" "${WORK_DIR}/asb.env"
    remove_legacy_symlink
    systemctl daemon-reload
    green "${PROJECT_NAME} 安装完成，服务检查通过。"
  else
    yellow "安装已完成，但服务检查未全部通过；请修复后再使用节点。"
    if ((LEGACY_MIGRATED)); then
      systemctl disable --now "${TRAFFIC_TIMER}.timer" "$CORE_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
      systemctl restart "$PREVIOUS_CORE_SERVICE" "$PREVIOUS_ARGO_SERVICE" \
        "$LEGACY_CORE_SERVICE" "$LEGACY_ARGO_SERVICE" 2>/dev/null || true
      yellow "已恢复旧服务并保留旧目录兼容链接。"
    fi
  fi
  section "运行状态"
  state_value "Argo Tunnel" "$(service_status "$ARGO_SERVICE")"
  state_value "代理核心" "$(service_status "$CORE_SERVICE") · $(core_label)"
  state_value "WARP" "$(warp_status)"
  state_value "多路复用" "已启用 · h2mux"
  state_value "TCP Brutal" "$(tcp_brutal_status)"
  key_value "Argo 域名" "$ARGO_DOMAIN"
  endpoint_value "优选入口" "$SERVER" "$SERVER_PORT"
  key_value "Argo 回源" "127.0.0.1:${ORIGIN_PORT}"
  key_value "组件版本" "$(component_versions)"
  key_value "节点文件" "$NODES_FILE"
  key_value "管理命令" "${COMMAND_NAME} / ${COMMAND_NAME_UPPER}"
  show_install_nodes
}

install_menu() {
  local choice
  while true; do
    brand "${PROJECT_NAME} · 项目安装" back
    subsection "安装方式"
    menu_item 1 "本地重装"
    menu_item 2 "在线更新"
    menu_hint "在线更新会先校验并替换本地脚本。"
    menu_item 0 "返回上级"
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
    "/etc/systemd/system/${CORE_SERVICE}.service" "/etc/systemd/system/${ARGO_SERVICE}.service" \
    "/etc/systemd/system/${TRAFFIC_SERVICE}.service" "/etc/systemd/system/${TRAFFIC_TIMER}.timer" \
    "$NODES_FILE" "$SUB_FILE" "$SUB_BASE64_FILE" "$SUB_CLASH_FILE" \
    "$SUB_SING_BOX_FILE" "$SUB_AUTO_QR_FILE" \
    "$CONFIG_SNAPSHOT/" 2>/dev/null || true
}

apply_runtime_config() {
  local snapshot="${CONFIG_SNAPSHOT:-}"
  local services=(nginx "$CORE_SERVICE" "$ARGO_SERVICE")
  [[ -n "$snapshot" && -d "$snapshot" ]] || die "缺少配置事务快照。"
  info "正在应用配置并重启服务..."
  if save_env && write_available_core_configs && write_nginx_config && write_services &&
    generate_nodes &&
    systemctl daemon-reload &&
    systemctl restart "${services[@]}" && wait_for_services "${services[@]}"; then
    rm -rf "$snapshot"
    green "配置已生效。"
    return 0
  fi
  red "配置验证失败，正在恢复。"
  report_runtime_config_failure "${services[@]}"
  [[ -f "$snapshot/$(basename "$ENV_FILE")" ]] && install -m 600 "$snapshot/$(basename "$ENV_FILE")" "$ENV_FILE"
  [[ -f "$snapshot/nodes.conf" ]] && install -m 600 "$snapshot/nodes.conf" "$NODES_CONFIG"
  [[ -f "$snapshot/sing-box.json" ]] && install -m 600 "$snapshot/sing-box.json" "$SING_BOX_CONFIG"
    [[ -f "$snapshot/$(basename "$NGINX_CONFIG")" ]] && install -m 644 "$snapshot/$(basename "$NGINX_CONFIG")" "$NGINX_CONFIG"
  [[ -f "$snapshot/${CORE_SERVICE}.service" ]] && install -m 600 "$snapshot/${CORE_SERVICE}.service" "/etc/systemd/system/${CORE_SERVICE}.service"
  [[ -f "$snapshot/${ARGO_SERVICE}.service" ]] && install -m 600 "$snapshot/${ARGO_SERVICE}.service" "/etc/systemd/system/${ARGO_SERVICE}.service"
  [[ -f "$snapshot/${TRAFFIC_SERVICE}.service" ]] && install -m 600 "$snapshot/${TRAFFIC_SERVICE}.service" "/etc/systemd/system/${TRAFFIC_SERVICE}.service"
  [[ -f "$snapshot/${TRAFFIC_TIMER}.timer" ]] && install -m 600 "$snapshot/${TRAFFIC_TIMER}.timer" "/etc/systemd/system/${TRAFFIC_TIMER}.timer"
  rm -f "$NODES_FILE" "$SUB_FILE" "$SUB_BASE64_FILE" "$SUB_CLASH_FILE" \
    "$SUB_SING_BOX_FILE" "$SUB_AUTO_QR_FILE"
  [[ -f "$snapshot/$(basename "$NODES_FILE")" ]] && install -m 600 "$snapshot/$(basename "$NODES_FILE")" "$NODES_FILE"
  [[ -f "$snapshot/$(basename "$SUB_FILE")" ]] && install -m 644 "$snapshot/$(basename "$SUB_FILE")" "$SUB_FILE"
  [[ -f "$snapshot/$(basename "$SUB_BASE64_FILE")" ]] && install -m 644 "$snapshot/$(basename "$SUB_BASE64_FILE")" "$SUB_BASE64_FILE"
  [[ -f "$snapshot/$(basename "$SUB_CLASH_FILE")" ]] && install -m 644 "$snapshot/$(basename "$SUB_CLASH_FILE")" "$SUB_CLASH_FILE"
  [[ -f "$snapshot/$(basename "$SUB_SING_BOX_FILE")" ]] && install -m 644 "$snapshot/$(basename "$SUB_SING_BOX_FILE")" "$SUB_SING_BOX_FILE"
  [[ -f "$snapshot/$(basename "$SUB_AUTO_QR_FILE")" ]] && install -m 644 "$snapshot/$(basename "$SUB_AUTO_QR_FILE")" "$SUB_AUTO_QR_FILE"
  rm -rf "$snapshot"
  load_env
  systemctl daemon-reload
  systemctl restart nginx "$CORE_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
  die "配置未生效，已恢复原配置。"
}

list_node_profiles() {
  local mode="${1:-compact}" tag protocol path port socks direct_ip
  direct_ip="$(public_ipv4)"
  if [[ "$mode" == "spaced" ]]; then
    printf '\n'
    UI_TIGHT_SECTION=1
  fi
  subsection "节点列表"
  printf '%s%s' "$C_BOLD" "$C_BRIGHT_CYAN"
  pad_right "标签" 13; printf '  '; pad_right "协议" 6; printf '  '; pad_right "传输路径" 14
  printf '  '; pad_right "端口" 5; printf '  %s%s\n' "出站 IP" "$C_RESET"
  printf '%s%s%s\n' "$C_DIM" '-------------  ------  --------------  -----  ------------------' "$C_RESET"
  while IFS='|' read -r tag protocol path port socks; do
    printf '%s' "$C_BRIGHT_WHITE"; fit_text "$tag" 13; printf '%s  %s' "$C_RESET" "$C_BRIGHT_BLUE"
    fit_text "$(protocol_label "$protocol")" 6; printf '%s  %s' "$C_RESET" "$C_BRIGHT_WHITE"; fit_text "$path" 14
    printf '%s  %s' "$C_RESET" "$C_BRIGHT_YELLOW"; fit_text "$port" 5; printf '%s  %s' "$C_RESET" "$C_BRIGHT_MAGENTA"
    if [[ -n "$socks" ]]; then
      fit_text "$(node_outbound_value "$socks")" 18; printf '%s\n' "$C_RESET"
    else
      fit_text "${direct_ip:-未知}" 18; printf '%s\n' "$C_RESET"
    fi
  done <"$NODES_CONFIG"
}

add_node_profile() {
  local tag protocol path port socks default_port
  brand "${PROJECT_NAME} · 添加节点" cancel
  begin_config_change
  default_port="$(next_node_port)"
  section "节点参数"
  while true; do
    read_input "节点标签 [字母/数字/_/-]：" tag
    is_exit_input "$tag" && { cancel_config_change; return 0; }
    [[ "$tag" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || { yellow "节点标签格式错误，请重新输入。"; continue; }
    awk -F'|' -v tag="$tag" '$1 == tag {found=1} END {exit !found}' "$NODES_CONFIG" &&
      { yellow "节点标签已存在，请重新输入。"; continue; }
    break
  done
  while true; do
    read_input "节点协议 [vless/vmess/trojan]：" protocol
    is_exit_input "$protocol" && { cancel_config_change; return 0; }
    protocol="${protocol,,}"
    [[ "$protocol" =~ ^(vless|vmess|trojan)$ ]] || { yellow "协议不受支持，请重新输入。"; continue; }
    break
  done
  while true; do
    read_input "传输路径 [以 / 开头]：" path
    is_exit_input "$path" && { cancel_config_change; return 0; }
    valid_path "$path" || { yellow "传输路径格式错误，请重新输入。"; continue; }
    awk -F'|' -v path="$path" '$3 == path {found=1} END {exit !found}' "$NODES_CONFIG" &&
      { yellow "传输路径已存在，请重新输入。"; continue; }
    break
  done
  while true; do
    read_input "监听端口 [${default_port}]：" port
    is_exit_input "$port" && { cancel_config_change; return 0; }
    port="${port:-$default_port}"
    valid_port "$port" || { yellow "端口格式错误，请重新输入。"; continue; }
    ((10#$port != 10#$STATS_API_PORT)) || { yellow "该端口由流量统计 API 使用，请重新输入。"; continue; }
    awk -F'|' -v port="$port" '$4 == port {found=1} END {exit !found}' "$NODES_CONFIG" &&
      { yellow "监听端口已存在，请重新输入。"; continue; }
    break
  done
  while true; do
    read_input "SOCKS5 出站 [主机:端口:用户名:密码，留空直连]：" socks
    is_exit_input "$socks" && { cancel_config_change; return 0; }
    [[ -z "$socks" ]] || valid_socks5 "$socks" || { yellow "SOCKS5 格式错误，请重新输入。"; continue; }
    break
  done
  printf '%s|%s|%s|%s|%s\n' "$tag" "$protocol" "$path" "$port" "$socks" >>"$NODES_CONFIG"
  validate_nodes_config
  apply_runtime_config
}

change_origin_port() {
  local value temp next_port
  brand "${PROJECT_NAME} · Argo Tunnel 回源端口" default
  subsection "当前配置"
  key_value "回源端口" "$ORIGIN_PORT"
  section "修改配置"
  begin_config_change
  read_input "Argo Tunnel 回源端口 [${ORIGIN_PORT}]：" value
  is_exit_input "$value" && { cancel_config_change; return 0; }
  value="${value:-$ORIGIN_PORT}"
  valid_port "$value" || die "端口格式错误。"
  ((10#$value != 10#$STATS_API_PORT)) || die "Argo 回源端口不能占用流量统计 API 端口 ${STATS_API_PORT}。"
  next_port="$((10#$value + 1))"
  ((next_port + $(wc -l <"$NODES_CONFIG") - 1 <= 65535)) ||
    die "端口过大，无法为全部节点顺延监听端口。"
  ! ((10#$STATS_API_PORT >= next_port && 10#$STATS_API_PORT < next_port + $(wc -l <"$NODES_CONFIG"))) ||
    die "顺延后的节点端口会占用流量统计 API 端口 ${STATS_API_PORT}。"
  temp="$(mktemp)"
  awk -F'|' -v OFS='|' -v port="$next_port" '{$4=port++; print}' "$NODES_CONFIG" >"$temp"
  install -m 600 "$temp" "$NODES_CONFIG"
  rm -f "$temp"
  ORIGIN_PORT="$value"
  apply_runtime_config
  info "Cloudflare Public Hostname 的 Service 请同步改为 http://localhost:${ORIGIN_PORT}。"
}

delete_node_profile() {
  local tag temp answer
  brand "${PROJECT_NAME} · 删除节点" cancel
  list_node_profiles
  section "删除操作"
  begin_config_change
  [[ "$(wc -l <"$NODES_CONFIG")" -gt 1 ]] || { cancel_config_change; yellow "至少必须保留一个节点。"; return 0; }
  while true; do
    read_input "节点标签：" tag
    is_exit_input "$tag" && { cancel_config_change; return 0; }
    awk -F'|' -v wanted="$tag" '$1 == wanted {found=1} END {exit !found}' "$NODES_CONFIG" && break
    yellow "未找到节点标签：${tag}，请重新输入。"
  done
  read_input "确认删除节点 ${tag}？[Y/n]：" answer
  is_exit_input "$answer" && { cancel_config_change; return 0; }
  is_confirmed "$answer" || { cancel_config_change; return 0; }
  temp="$(mktemp)"
  awk -F'|' -v wanted="$tag" '$1 != wanted' "$NODES_CONFIG" >"$temp"
  install -m 600 "$temp" "$NODES_CONFIG"
  rm -f "$temp"
  apply_runtime_config
}

edit_node_profile() {
  local wanted tag protocol path port socks new_tag new_protocol new_path new_port new_socks temp
  brand "${PROJECT_NAME} · 修改节点" default
  list_node_profiles
  section "选择节点"
  while true; do
    tag=""
    read_input "节点标签：" wanted
    is_exit_input "$wanted" && { return_notice; return 0; }
    while IFS='|' read -r tag protocol path port socks; do
      [[ "$tag" == "$wanted" ]] && break
    done <"$NODES_CONFIG"
    [[ "${tag:-}" == "$wanted" ]] && break
    yellow "未找到节点标签：${wanted}，请重新输入。"
  done
  begin_config_change
  section "新的节点参数"
  while true; do
    read_input "节点标签 [${tag}]：" new_tag
    is_exit_input "$new_tag" && { cancel_config_change; return 0; }
    new_tag="${new_tag:-$tag}"
    [[ "$new_tag" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*$ ]] || { yellow "节点标签格式错误，请重新输入。"; continue; }
    awk -F'|' -v wanted="$wanted" -v value="$new_tag" '$1 != wanted && $1 == value {found=1} END {exit !found}' "$NODES_CONFIG" &&
      { yellow "节点标签已被其他节点使用，请重新输入。"; continue; }
    tag="$new_tag"; break
  done
  while true; do
    read_input "节点协议 [${protocol}]：" new_protocol
    is_exit_input "$new_protocol" && { cancel_config_change; return 0; }
    new_protocol="${new_protocol:-$protocol}"; new_protocol="${new_protocol,,}"
    [[ "$new_protocol" =~ ^(vless|vmess|trojan)$ ]] || { yellow "协议不受支持，请重新输入。"; continue; }
    protocol="$new_protocol"; break
  done
  while true; do
    read_input "传输路径 [${path}]：" new_path
    is_exit_input "$new_path" && { cancel_config_change; return 0; }
    new_path="${new_path:-$path}"
    valid_path "$new_path" || { yellow "传输路径格式错误，请重新输入。"; continue; }
    awk -F'|' -v wanted="$wanted" -v value="$new_path" '$1 != wanted && $3 == value {found=1} END {exit !found}' "$NODES_CONFIG" &&
      { yellow "传输路径已被其他节点使用，请重新输入。"; continue; }
    path="$new_path"; break
  done
  while true; do
    read_input "监听端口 [${port}]：" new_port
    is_exit_input "$new_port" && { cancel_config_change; return 0; }
    new_port="${new_port:-$port}"
    valid_port "$new_port" || { yellow "端口格式错误，请重新输入。"; continue; }
    ((10#$new_port != 10#$STATS_API_PORT)) || { yellow "该端口由流量统计 API 使用，请重新输入。"; continue; }
    awk -F'|' -v wanted="$wanted" -v value="$new_port" '$1 != wanted && $4 == value {found=1} END {exit !found}' "$NODES_CONFIG" &&
      { yellow "监听端口已被其他节点使用，请重新输入。"; continue; }
    port="$new_port"; break
  done
  while true; do
    read_input "SOCKS5 [$(node_outbound_value "$socks")；- 为 direct]：" new_socks
    is_exit_input "$new_socks" && { cancel_config_change; return 0; }
    [[ "$new_socks" == "-" ]] && new_socks="" || new_socks="${new_socks:-$socks}"
    [[ -z "$new_socks" ]] || valid_socks5 "$new_socks" || { yellow "SOCKS5 格式错误，请重新输入。"; continue; }
    socks="$new_socks"; break
  done
  temp="$(mktemp)"
  awk -F'|' -v OFS='|' -v wanted="$wanted" -v tag="$tag" -v protocol="$protocol" \
    -v path="$path" -v port="$port" -v socks="$socks" \
    '$1 == wanted {$1=tag; $2=protocol; $3=path; $4=port; $5=socks} {print}' "$NODES_CONFIG" >"$temp"
  install -m 600 "$temp" "$NODES_CONFIG"; rm -f "$temp"
  validate_nodes_config
  apply_runtime_config
}

configure_warp() {
  local choice port targets domain normalized output item old_ifs answer
  while true; do
    brand "${PROJECT_NAME} · WARP 分流" back
    subsection "当前状态"
    state_value "WARP" "$(warp_status)"
    key_value "代理端口" "$WARP_PROXY_PORT"
    key_value "目标域名" "${WARP_DOMAINS:-无}"
    subsection "WARP 操作"
    menu_item 1 "启用配置"
    menu_item 2 "添加域名"
    menu_item 3 "删除域名"
    menu_item 3 "停用 WARP"
    menu_item 0 "返回上级"
    ui_line
    read_choice "请选择："; choice="$REPLY"
    case "$choice" in
      1)
        brand "${PROJECT_NAME} · WARP 配置" default
        subsection "当前配置"
        state_value "WARP" "$(warp_status)"
        key_value "代理端口" "$WARP_PROXY_PORT"
        key_value "目标域名" "${WARP_DOMAINS:-无}"
        section "修改配置"
        read_input "WARP 本地 SOCKS5 端口 [${WARP_PROXY_PORT}]：" port
        is_exit_input "$port" && { return_notice; continue; }
        port="${port:-$WARP_PROXY_PORT}"
        valid_port "$port" || die "WARP 代理端口无效。"
        ((10#$port != 10#$STATS_API_PORT)) || die "WARP 代理端口不能占用流量统计 API 端口 ${STATS_API_PORT}。"
        read_input "WARP 目标 [网址或域名，逗号分隔；${WARP_DOMAINS:-无}]：" targets
        is_exit_input "$targets" && { return_notice; continue; }
        targets="${targets:-$WARP_DOMAINS}"
        targets="$(normalize_warp_domains "$targets")"
        install_cloudflare_warp
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
        read_input "新增目标 [网址或域名，可用逗号分隔]：" targets
        is_exit_input "$targets" && { return_notice; continue; }
        [[ -n "$targets" ]] || continue
        targets="$(normalize_warp_domains "$targets")"
        begin_config_change
        WARP_DOMAINS="$(normalize_warp_domains "${WARP_DOMAINS},${targets}")"
        apply_runtime_config
        ;;
      3)
        [[ "$WARP_ENABLED" == "1" ]] || die "WARP 分流尚未启用。"
        read_input "要删除的目标：" domain
        is_exit_input "$domain" && { return_notice; continue; }
        [[ -n "$domain" ]] || continue
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
        read_input "确认停用 WARP 分流？[Y/n]：" answer
        is_exit_input "$answer" && { return_notice; continue; }
        is_confirmed "$answer" || { yellow "已取消停用 WARP 分流。"; continue; }
        begin_config_change
        WARP_ENABLED=0; WARP_DOMAINS=""
        apply_runtime_config
        ;;
      0) return ;;
      *) yellow "请输入 0 到 4。" ;;
    esac
  done
}

install_tcp_brutal_module() {
  local answer installer module_archive actual_sha supported=0 packages
  tcp_brutal_preflight && supported=1
  brand "${PROJECT_NAME} · TCP Brutal 安装" cancel
  subsection "内核预检"
  key_value "当前内核" "${TCP_BRUTAL_CHECKED_KERNEL:-未知}"
  if ((supported)); then
    green "当前内核支持安装 TCP Brutal DKMS 模块。"
    key_value "内核头文件" "$TCP_BRUTAL_HEADERS_STATE"
    [[ -z "$TCP_BRUTAL_SUPPORT_WARNING" ]] || yellow "$TCP_BRUTAL_SUPPORT_WARNING"
  else
    red "$TCP_BRUTAL_SUPPORT_ERROR"
    menu_hint "未执行下载、软件包安装或内核模块变更。"
    return 0
  fi
  detect_tcp_brutal
  if [[ "$IS_BRUTAL" == "true" ]]; then
    state_value "模块状态" "已加载 · 将检查更新"
  else
    state_value "模块状态" "未安装或未加载"
  fi
  section "安装说明"
  menu_hint "来源：apernet/tcp-brutal 官方 DKMS 安装器"
  menu_hint "将安装 DKMS、当前内核头文件并配置开机加载。"
  read_input "确认安装或更新 TCP Brutal？[Y/n]：" answer
  is_exit_input "$answer" && { return_notice; return 0; }
  is_confirmed "$answer" || { yellow "已取消 TCP Brutal 安装。"; return 0; }

  info "正在刷新 APT 并复核当前内核的官方安装条件..."
  apt-get update || die "APT 软件包索引更新失败，无法复核 TCP Brutal 安装条件。"
  tcp_brutal_preflight || die "$TCP_BRUTAL_SUPPORT_ERROR"
  packages=(curl ca-certificates kmod dkms)
  [[ -z "$TCP_BRUTAL_HEADERS_PACKAGE" ]] || packages+=("$TCP_BRUTAL_HEADERS_PACKAGE")
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}" ||
    die "TCP Brutal 安装依赖准备失败。"
  tcp_brutal_headers_directory_exists "$TCP_BRUTAL_CHECKED_KERNEL" ||
    die "当前运行内核的匹配头文件安装后仍不可用：/lib/modules/${TCP_BRUTAL_CHECKED_KERNEL}/build"
  installer="$(mktemp)"
  download "https://raw.githubusercontent.com/${TCP_BRUTAL_REPO}/${TCP_BRUTAL_INSTALLER_REV}/scripts/install_dkms.sh" "$installer"
  actual_sha="$(sha256sum "$installer" | awk '{print $1}')"
  if [[ "$actual_sha" != "$TCP_BRUTAL_INSTALLER_SHA256" ]]; then
    rm -f "$installer"
    die "TCP Brutal 官方安装器 SHA256 校验失败。"
  fi
  bash -n "$installer" || { rm -f "$installer"; die "TCP Brutal 官方安装器语法检查失败。"; }
  chmod 700 "$installer"
  module_archive="$(mktemp --suffix=.tar.gz)"
  download "https://github.com/${TCP_BRUTAL_REPO}/releases/download/v${TCP_BRUTAL_VERSION}/tcp-brutal.dkms.tar.gz" "$module_archive"
  actual_sha="$(sha256sum "$module_archive" | awk '{print $1}')"
  if [[ "$actual_sha" != "$TCP_BRUTAL_DKMS_SHA256" ]]; then
    rm -f "$installer" "$module_archive"
    die "TCP Brutal DKMS 模块包 SHA256 校验失败。"
  fi
  tar -tzf "$module_archive" >/dev/null || {
    rm -f "$installer" "$module_archive"
    die "TCP Brutal DKMS 模块包结构无效。"
  }
  info "正在安装已固定并校验的 TCP Brutal v${TCP_BRUTAL_VERSION}..."
  if ! bash "$installer" install --local "$module_archive"; then
    rm -f "$installer" "$module_archive"
    die "TCP Brutal 官方安装器执行失败。"
  fi
  rm -f "$installer" "$module_archive"
  detect_tcp_brutal
  [[ "$IS_BRUTAL" == "true" ]] || die "TCP Brutal 已安装但 brutal 模块未能加载。"

  begin_config_change
  apply_runtime_config
  green "TCP Brutal 已安装并加载，服务端与订阅配置已同步。"
}

configure_transport_optimization() {
  local choice value new_up new_down
  while true; do
    brand "${PROJECT_NAME} · 传输优化" back
    subsection "当前状态"
    state_value "多路复用" "已启用 · h2mux · ${MULTIPLEX_MAX_STREAMS} streams"
    state_value "TCP Brutal" "$(tcp_brutal_status)"
    key_value "上传带宽" "${BRUTAL_UP_MBPS} Mbps"
    key_value "下载带宽" "${BRUTAL_DOWN_MBPS} Mbps"
    section "传输操作"
    menu_item 1 "安装 / 更新 TCP Brutal"
    menu_item 2 "设置 Brutal 带宽"
    menu_item 0 "返回上级"
    ui_line
    read_choice "请选择："; choice="$REPLY"
    case "$choice" in
      1) install_tcp_brutal_module ;;
      2)
        read_input "上传带宽 Mbps [${BRUTAL_UP_MBPS}]：" value
        is_exit_input "$value" && { return_notice; continue; }
        new_up="${value:-$BRUTAL_UP_MBPS}"
        valid_bandwidth_mbps "$new_up" || { yellow "请输入 1 到 100000 的整数。"; continue; }
        read_input "下载带宽 Mbps [${BRUTAL_DOWN_MBPS}]：" value
        is_exit_input "$value" && { return_notice; continue; }
        new_down="${value:-$BRUTAL_DOWN_MBPS}"
        valid_bandwidth_mbps "$new_down" || { yellow "请输入 1 到 100000 的整数。"; continue; }
        begin_config_change
        BRUTAL_UP_MBPS="$new_up"
        BRUTAL_DOWN_MBPS="$new_down"
        apply_runtime_config
        ;;
      0) return ;;
      *) yellow "请输入 0、1 或 2。" ;;
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
    brand "${PROJECT_NAME} · 参数配置" back
    subsection "Argo 配置"
    menu_item 1 "Token 与域名"
    menu_item 2 "优选入口"
    menu_item 3 "回源端口"
    menu_item 4 "全局 UUID"
    section "节点配置"
    menu_item 5 "查看节点"
    menu_item 6 "添加节点"
    menu_item 7 "修改节点"
    menu_item 8 "删除节点"
    section "WARP 配置"
    menu_item 9 "WARP 分流"
    section "传输配置"
    menu_item 10 "h2mux / TCP Brutal"
    menu_item 0 "返回上级"
    ui_line
    read_choice "请选择："; choice="$REPLY"
    case "$choice" in
      1)
        brand "${PROJECT_NAME} · Token / Argo 域名" default
        subsection "当前配置"
        key_value "Argo 域名" "$ARGO_DOMAIN"
        state_value "Token 状态" "$([[ -n "$ARGO_TOKEN" ]] && printf '已配置' || printf '未配置')"
        section "修改配置"
        begin_config_change
        read_input "Argo Token [$([[ -n "$ARGO_TOKEN" ]] && printf '已配置' || printf '必填')]：" value
        is_exit_input "$value" && { cancel_config_change; continue; }
        ARGO_TOKEN="${value:-$ARGO_TOKEN}"
        read_input "Argo 域名 [${ARGO_DOMAIN}]：" value
        is_exit_input "$value" && { cancel_config_change; continue; }
        ARGO_DOMAIN="${value:-$ARGO_DOMAIN}"
        valid_argo_token "$ARGO_TOKEN" && [[ "$ARGO_DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] ||
          die "Token 或域名无效。"
        apply_runtime_config
        ;;
      2)
        brand "${PROJECT_NAME} · Cloudflare 优选入口" default
        subsection "当前配置"
        endpoint_value "当前入口" "$SERVER" "$SERVER_PORT"
        section "修改配置"
        begin_config_change
        read_input "优选入口 [${SERVER}:${SERVER_PORT}]：" endpoint
        is_exit_input "$endpoint" && { cancel_config_change; continue; }
        endpoint="${endpoint:-${SERVER}:${SERVER_PORT}}"
        parse_endpoint "$endpoint"
        apply_runtime_config
        ;;
      3) change_origin_port ;;
      4)
        brand "${PROJECT_NAME} · 全局 UUID" default
        subsection "当前配置"
        key_value "全局 UUID" "$UUID"
        section "修改配置"
        begin_config_change
        read_input "全局 UUID [${UUID}]：" value
        is_exit_input "$value" && { cancel_config_change; continue; }
        value="${value:-$UUID}"
        valid_uuid "$value" || die "UUID 格式错误。"
        UUID="$value"
        apply_runtime_config
        ;;
      5) list_node_profiles spaced ;;
      6) add_node_profile ;;
      7) edit_node_profile ;;
      8) delete_node_profile ;;
      9) configure_warp ;;
      10) configure_transport_optimization ;;
      0) return ;;
      *) yellow "请输入 0 到 10。" ;;
    esac
  done
}

backup_project() {
  local output="${1:-}" backup_dir temp_archive stage manifest_dir
  require_root
  [[ -f "$MANAGED_FILE" ]] || die "缺少项目所有权标记，拒绝备份。"
  [[ -f "$NODES_CONFIG" ]] || die "节点配置不存在：${NODES_CONFIG}"
  brand "${PROJECT_NAME} · 备份节点配置" default
  subsection "备份配置"
  key_value "节点配置" "$NODES_CONFIG"
  key_value "默认目录" "$BACKUP_DIR"
  validate_nodes_config
  if [[ -z "$output" ]]; then
    read_input "备份位置 [目录或 .tar.gz；${BACKUP_DIR}]：" output
    is_exit_input "$output" && { return_notice; return 0; }
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
    output="${backup_dir}/ags-nodes-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
  fi
  [[ "$output" == /* ]] || die "备份路径必须使用绝对路径。"
  [[ "$output" != "$WORK_DIR" ]] || die "备份不能直接保存到项目根目录。"
  if [[ "$output" == "$WORK_DIR/"* && "$output" != "$BACKUP_DIR/"* ]]; then
    die "项目目录内仅允许使用默认备份目录 ${BACKUP_DIR}。"
  fi
  install -d -m 700 "$(dirname "$output")"
  [[ "$output" == *.tar.gz ]] || die "备份文件必须以 .tar.gz 结尾。"
  stage="$(mktemp -d)"
  manifest_dir="${stage}/ags-nodes-backup"
  install -d -m 700 "$manifest_dir"
  install -m 600 "$NODES_CONFIG" "${manifest_dir}/nodes.conf"
  {
    printf 'type=nodes\n'
    printf 'project=%s\n' "$PROJECT_CODE"
    printf 'version=%s\n' "$VERSION"
    printf 'created_at=%s\n' "$(date -Iseconds)"
    printf 'source=%s\n' "$NODES_CONFIG"
  } >"${manifest_dir}/manifest"
  chmod 600 "${manifest_dir}/manifest"
  temp_archive="$(mktemp --suffix=.tar.gz)"
  info "正在创建节点配置备份..."
  if ! tar -C "$stage" -czf "$temp_archive" "ags-nodes-backup"; then
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
  if ! grep -Eq '^(ags-nodes-backup|argo-singbox-nodes-backup|argofusion-nodes-backup|afs|argofusion|asb-nodes-backup|asb)/nodes\.conf$' <<<"$members"; then
    die "备份归档不包含可恢复的节点配置 nodes.conf。"
  fi
}

restore_project() {
  local archive="${1:-}" stage archive_copy latest nodes_source
  require_root
  brand "${PROJECT_NAME} · 恢复节点配置" default
  subsection "恢复来源"
  key_value "默认目录" "$BACKUP_DIR"
  if [[ -z "$archive" ]]; then
    read_input "备份来源 [文件或目录；${BACKUP_DIR} 最新备份]：" archive
    is_exit_input "$archive" && { return_notice; return 0; }
    archive="${archive:-$BACKUP_DIR}"
  fi
  if [[ -d "$archive" ]]; then
    latest="$(find "$archive" -maxdepth 1 -type f \
      \( -name 'ags-nodes-backup-*.tar.gz' -o -name 'argo-singbox-nodes-backup-*.tar.gz' -o -name 'argofusion-nodes-backup-*.tar.gz' -o -name 'argofusion-backup-*.tar.gz' \
        -o -name 'asb-nodes-backup-*.tar.gz' -o -name 'asb-backup-*.tar.gz' \) \
      -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n1 | cut -d' ' -f2-)"
    [[ -n "$latest" ]] || die "备份目录中没有可恢复的归档：${archive}"
    archive="$latest"
    info "使用最新备份：${archive}"
  fi
  [[ -f "$archive" ]] || die "备份文件不存在：${archive}"
  [[ -f "$MANAGED_FILE" ]] || die "当前 ${WORK_DIR} 缺少项目所有权标记，拒绝恢复节点配置。"
  archive_copy="$(mktemp --suffix=.tar.gz)"
  cp -a "$archive" "$archive_copy"
  info "正在校验备份归档..."
  validate_backup_archive "$archive_copy"
  stage="$(mktemp -d)"
  tar --no-same-owner --no-same-permissions -xzf "$archive_copy" -C "$stage"
  if [[ -f "$stage/ags-nodes-backup/nodes.conf" ]]; then
    nodes_source="$stage/ags-nodes-backup/nodes.conf"
  elif [[ -f "$stage/argo-singbox-nodes-backup/nodes.conf" ]]; then
    nodes_source="$stage/argo-singbox-nodes-backup/nodes.conf"
  elif [[ -f "$stage/argofusion-nodes-backup/nodes.conf" ]]; then
    nodes_source="$stage/argofusion-nodes-backup/nodes.conf"
  elif [[ -f "$stage/asb-nodes-backup/nodes.conf" ]]; then
    nodes_source="$stage/asb-nodes-backup/nodes.conf"
    yellow "检测到旧项目节点备份，仅恢复其中的节点配置。"
  elif [[ -f "$stage/${WORK_DIR_NAME}/nodes.conf" ]]; then
    nodes_source="$stage/${WORK_DIR_NAME}/nodes.conf"
    yellow "检测到旧版完整备份，仅恢复其中的节点配置，不替换脚本或核心。"
  elif [[ -f "$stage/${PREVIOUS_WORK_DIR##*/}/nodes.conf" ]]; then
    nodes_source="$stage/${PREVIOUS_WORK_DIR##*/}/nodes.conf"
    yellow "检测到旧组合项目完整备份，仅恢复其中的节点配置。"
  elif [[ -f "$stage/asb/nodes.conf" ]]; then
    nodes_source="$stage/asb/nodes.conf"
    yellow "检测到旧项目完整备份，仅恢复其中的节点配置。"
  else
    rm -rf "$stage"; rm -f "$archive_copy"
    die "备份结构中缺少 nodes.conf。"
  fi
  begin_config_change
  info "正在恢复节点配置..."
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
  red "节点配置恢复失败，正在回滚。"
  yellow "已恢复到执行恢复操作前的状态。"
  die "节点配置恢复失败，已回滚到恢复前状态。"
}

backup_restore_menu() {
  local choice
  require_root
  while true; do
    brand "${PROJECT_NAME} · 备份恢复" back
    subsection "节点配置"
    key_value "节点配置" "$NODES_CONFIG"
    key_value "默认目录" "$BACKUP_DIR"
    subsection "备份恢复"
    menu_item 1 "节点备份"
    menu_item 2 "节点恢复"
    menu_item 0 "返回上级"
    ui_line
    read_choice "请选择："; choice="$REPLY"
    case "$choice" in
      1) backup_project ;;
      2) restore_project ;;
      0) return ;;
      *) yellow "请输入 0、1 或 2。" ;;
    esac
  done
}

colorize_journal() {
  local line level_color
  while IFS= read -r line; do
    level_color="$C_WHITE"
    [[ "$line" == *" INFO "* || "$line" == *" INFO["* ]] && level_color="$C_BRIGHT_GREEN"
    [[ "$line" == *" WARN "* || "$line" == *" WARNING "* ]] && level_color="$C_BRIGHT_YELLOW"
    [[ "$line" == *" ERROR "* || "$line" == *" ERROR["* ]] && level_color="$C_BRIGHT_RED"
    if [[ "$line" =~ ^([^[:space:]]+[[:space:]][^[:space:]]+)[[:space:]]+(.*)$ ]]; then
      printf '%s%s%s %s%s%s\n' "$C_DIM" "${BASH_REMATCH[1]}" "$C_RESET" \
        "$level_color" "${BASH_REMATCH[2]}" "$C_RESET"
    else
      printf '%s%s%s\n' "$level_color" "$line" "$C_RESET"
    fi
  done
}

filter_journal_noise() {
  grep -Ev 'infra/conf/serial: Reading config:|common/errors: The feature (WebSocket transport|VMess|Trojan).*deprecated'
}

doctor() {
  local failed=0 token_in_unit=0 warp_target ip memory directory mode log_errors=0 warnings=0
  require_root
  load_env
  ensure_nodes_config
  ip="$(curl -4fsS --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null ||
    hostname -I 2>/dev/null | awk '{print $1}')"
  memory="$(free -m | awk '/^Mem:/{printf "%s/%s MiB (%.0f%%)",$3,$2,$3*100/$2}')"
  brand "${PROJECT_NAME} · 运行诊断"
  subsection "系统与组件状态"
  ip_value "公网 IP" "${ip:-未知}"
  key_value "脚本版本" "v${VERSION}"
  key_value "组件版本" "$(component_versions)"
  key_value "内存" "${memory:-未知}"
  endpoint_value "优选入口" "${SERVER:-未知}" "${SERVER_PORT:-未知}"
  key_value "Argo 回源" "127.0.0.1:${ORIGIN_PORT}"
  state_value "多路复用" "已启用 · h2mux · ${MULTIPLEX_MAX_STREAMS} streams"
  state_value "TCP Brutal" "$(tcp_brutal_status)"
  section "配置检查"
  if validate_nodes_config && valid_uuid "$UUID" && valid_argo_token "$ARGO_TOKEN" &&
    [[ -n "$ARGO_DOMAIN" ]]; then
    green "AGS 配置已通过。"
  else
    red "AGS 配置无效。"
    failed=1
  fi
  if core_check >/dev/null 2>&1; then green "$(core_label) 配置已通过。"; else red "$(core_label) 配置无效。"; failed=1; fi
  if nginx -t >/dev/null 2>&1; then green "Nginx 配置已通过。"; else red "Nginx 配置无效。"; failed=1; fi
  detect_tcp_brutal
  if [[ "$IS_BRUTAL" == "true" ]]; then
    green "TCP Brutal 内核模块已加载。"
  else
    yellow "TCP Brutal 未启用：服务器缺少 brutal 内核模块。"
    warnings=1
  fi
  for directory in "$CONFIG_DIR" "$DATA_DIR" "$SUBSCRIPTION_DIR"; do
    mode="$(stat -c '%a' "$directory" 2>/dev/null || true)"
    case "$directory:$mode" in
      "$CONFIG_DIR:700") green "config 目录权限正确（700）。" ;;
      "$DATA_DIR:700") green "data 目录权限正确（700）。" ;;
      "$SUBSCRIPTION_DIR:755") green "subscriptions 目录权限正确（755）。" ;;
      *) red "$(basename "$directory") 目录权限异常（当前 ${mode:-不存在}）。"; failed=1 ;;
    esac
  done
  [[ -f "/etc/systemd/system/${ARGO_SERVICE}.service" ]] &&
    grep -Fq -- "--token ${ARGO_TOKEN}" "/etc/systemd/system/${ARGO_SERVICE}.service" && token_in_unit=1
  ((token_in_unit)) && green "Argo Token 已配置且服务文件一致。" || { red "Argo Token 缺失或服务文件未同步。"; failed=1; }
  section "服务检查"
  if systemctl is-active --quiet nginx; then green "Nginx 运行中。"; else red "Nginx 未运行。"; failed=1; fi
  if systemctl is-active --quiet "$CORE_SERVICE"; then green "$(core_label) Core 运行中。"; else red "$(core_label) Core 未运行。"; failed=1; fi
  if systemctl is-active --quiet "$ARGO_SERVICE"; then green "Argo Tunnel 运行中。"; else red "Argo Tunnel 未运行。"; failed=1; fi
  if [[ "$WARP_ENABLED" == "1" ]]; then
    if systemctl is-active --quiet warp-svc &&
      ss -lntH "sport = :${WARP_PROXY_PORT}" | grep -q .; then
      printf '%s✓ WARP：本地代理运行于 %s127.0.0.1:%s%s\n' \
        "$C_BRIGHT_GREEN" "$C_BRIGHT_WHITE" "$WARP_PROXY_PORT" "$C_RESET"
    else
      red "WARP：服务或本地代理端口异常"
      failed=1
    fi
    warp_target="${WARP_DOMAINS%%,*}"
    if curl -fsS --socks5-hostname "127.0.0.1:${WARP_PROXY_PORT}" --connect-timeout 5 \
      --max-time 10 -o /dev/null "https://${warp_target}"; then
      green "WARP 目标可访问：https://${warp_target}"
    else
      red "WARP 目标无法通过本地代理访问：https://${warp_target}"
      failed=1
    fi
  else
    yellow "WARP：未启用"
    warnings=1
  fi
  health_check ws || failed=1
  journalctl -u "$CORE_SERVICE" -u "$ARGO_SERVICE" -n 30 --no-pager -o short-iso 2>/dev/null |
    grep -qE ' ERROR | ERROR\[' && log_errors=1 || true
  section "诊断结果"
  if ((failed)); then
    red "诊断发现异常，请检查上方项目。"
  elif ((warnings)); then
    yellow "存在提示 · 0 错误 · ${warnings} 警告"
  else
    green "运行正常 · 0 错误 · 0 警告"
  fi
  if ((log_errors)); then
    section "错误日志"
    journalctl -u "$CORE_SERVICE" -u "$ARGO_SERVICE" -n 30 --no-pager -o short-iso 2>/dev/null |
      filter_journal_noise |
      colorize_journal || true
  fi
  return "$failed"
}

show_nodes() {
  local node tag protocol path port socks index=0 auto_url
  load_env
  [[ -f "$NODES_FILE" ]] || die "节点文件不存在，请先安装。"
  auto_url="https://${ARGO_DOMAIN}/${UUID}/auto"
  brand "${PROJECT_NAME} · 节点订阅"
  UI_TIGHT_SECTION=1
  subsection "订阅链接"
  link_value "订阅面板" "https://${ARGO_DOMAIN}/${UUID}/"
  link_value "自适应订阅" "$auto_url"
  link_value "原始节点订阅" "https://${ARGO_DOMAIN}/${UUID}/raw"
  link_value "Base64 订阅" "https://${ARGO_DOMAIN}/${UUID}/base64"
  link_value "Clash/Mihomo 订阅" "https://${ARGO_DOMAIN}/${UUID}/clash"
  link_value "Sing-box 订阅" "https://${ARGO_DOMAIN}/${UUID}/sing-box"
  if command -v qrencode >/dev/null 2>&1; then
    section "自动适配 QR"
    qrencode -t ANSIUTF8 "$auto_url"
  fi
  section "原始节点"
  while IFS='|' read -r tag protocol path port socks; do
    IFS= read -r node <&3 || break
    ((index+=1))
    ((index > 1)) && printf '\n'
    printf '%s%s[%02d]%s %s%s%s %s· %s%s\n%s%s%s\n' \
      "$C_BOLD" "$C_BRIGHT_CYAN" "$index" "$C_RESET" "$C_BRIGHT_MAGENTA" "$tag" "$C_RESET" \
      "$C_BRIGHT_WHITE" "$(node_type_label "$protocol")" "$C_RESET" \
      "$C_BRIGHT_WHITE" "$node" "$C_RESET"
  done <"$NODES_CONFIG" 3<"$NODES_FILE"
  printf '\n'
}

toggle_service() {
  local service="$1" label="$2"
  require_root
  systemctl list-unit-files "${service}.service" --no-legend 2>/dev/null | grep -q "^${service}.service" ||
    die "${label} 尚未安装。"
  brand "${PROJECT_NAME} · ${label}"
  subsection "服务状态"
  state_value "$label" "$(service_status "$service")"
  if systemctl is-active --quiet "$service"; then
    info "正在停止 ${label}..."
    systemctl disable --now "$service"
    yellow "${label} 已停止。"
  else
    info "正在启动 ${label}..."
    systemctl enable --now "$service"
    green "${label} 已启动。"
  fi
}

manage_services() {
  local choice
  require_root
  while true; do
    load_env
    brand "${PROJECT_NAME} · 服务启停" back
    subsection "服务状态"
    state_value "Argo Tunnel" "$(service_status "$ARGO_SERVICE")"
    state_value "代理核心" "$(service_status "$CORE_SERVICE") · $(core_label)"
    section "服务操作"
    menu_item 1 "Argo 启停"
    menu_item 2 "核心启停"
    menu_item 3 "重启服务"
    menu_item 0 "返回上级"
    ui_line
    read_choice "请选择："; choice="$REPLY"
    case "$choice" in
      1) toggle_service "$ARGO_SERVICE" "Argo Tunnel" ;;
      2) toggle_service "$CORE_SERVICE" "$(core_label) Core" ;;
      3) restart_services ;;
      0) return ;;
      *) yellow "请输入 0、1、2 或 3。" ;;
    esac
  done
}

sync_versions() {
  local old_argo old_core new_argo new_core wanted_core wanted_argo core_target
  local core_stage="" staged_config="" argo_stage="" backup_stamp answer update_core=0 update_argo=0
  local services=()
  require_root
  [[ -f "$ENV_FILE" ]] || die "${PROJECT_NAME} 尚未安装。"
  load_env
  ensure_nodes_config
  validate_nodes_config
  [[ -f "/etc/systemd/system/${ARGO_SERVICE}.service" && -f "/etc/systemd/system/${CORE_SERVICE}.service" ]] ||
    die "Argo 或代理核心服务文件不存在，请先执行安装。"
  brand "${PROJECT_NAME} · 组件更新" back
  detect_arch
  old_argo="$(local_cloudflared_version || true)"
  old_core="$(local_core_version || true)"
  wanted_core="$(get_core_version)"
  wanted_argo="$(get_cloudflared_version)"
  new_core="$wanted_core"
  new_argo="$wanted_argo"
  section "Argo Tunnel（cloudflared）"
  key_value "当前版本" "${old_argo:-未安装}"
  key_value "目标版本" "${new_argo:-未知}"
  if [[ "$old_argo" != "$new_argo" ]]; then
    read_input "确认更新 cloudflared？[Y/n]：" answer
    is_exit_input "$answer" && { return_notice; return 0; }
    is_confirmed "$answer" && update_argo=1
  else
    green "cloudflared 已是目标版本。"
  fi
  section "$(core_label) 核心"
  key_value "当前版本" "${old_core:-未安装}"
  key_value "目标版本" "${new_core:-未知}"
  if [[ "$old_core" != "$new_core" ]]; then
    read_input "确认更新 $(core_label)？[Y/n]：" answer
    is_exit_input "$answer" && { return_notice; return 0; }
    is_confirmed "$answer" && update_core=1
  else
    green "$(core_label) 已是目标版本。"
  fi
  if [[ "$old_core" == "$new_core" && "$old_argo" == "$new_argo" ]]; then
    return 0
  fi
  if ((update_core == 0 && update_argo == 0)); then
    yellow "未选择需要更新的组件。"
    return 0
  fi
  if ((update_core)); then
    core_stage="$(mktemp)"
    staged_config="$(mktemp)"
    stage_core "$wanted_core" "$core_stage"
    write_sing_box_config "$staged_config" "$core_stage"
  fi
  if ((update_argo)); then
    argo_stage="$(mktemp)"
    stage_cloudflared "$wanted_argo" "$argo_stage"
  fi
  backup_stamp="${BACKUP_DIR}/core-$(date +%Y%m%d-%H%M%S)"
  install -d -m 700 "$backup_stamp"
  core_target="$(core_binary)"
  if ((update_core)); then
    cp -a "$core_target" "$backup_stamp/"
    cp -a "$SING_BOX_CONFIG" "$backup_stamp/"
  fi
  ((update_argo)) && cp -a "$BIN_DIR/cloudflared" "$backup_stamp/"
  if ((update_core)); then
    install -m 755 "$core_stage" "${core_target}.new"
    mv -f "${core_target}.new" "$core_target"
    install -m 600 "$staged_config" "${SING_BOX_CONFIG}.new"
    mv -f "${SING_BOX_CONFIG}.new" "$SING_BOX_CONFIG"
    services+=("$CORE_SERVICE")
  fi
  if ((update_argo)); then
    install -m 755 "$argo_stage" "${BIN_DIR}/cloudflared.new"
    mv -f "${BIN_DIR}/cloudflared.new" "$BIN_DIR/cloudflared"
    services+=("$ARGO_SERVICE")
  fi
  rm -f "$core_stage" "$staged_config" "$argo_stage"
  if systemctl restart "${services[@]}" &&
    wait_for_services && core_check; then
    if ((update_core)); then
      ensure_traffic_database || yellow "官方核心已更新，但全局流量账本未能初始化。"
    fi
    rm -rf "$backup_stamp"
    printf '\n'
    ((update_argo)) && green "cloudflared 已更新：${old_argo:-无} → ${new_argo}"
    ((update_core)) && green "$(core_label) 已更新：${old_core:-无} → ${new_core}"
    return 0
  else
    red "更新后验证失败，正在自动回滚。"
    if ((update_core)); then
      install -m 755 "$backup_stamp/$(basename "$core_target")" "$core_target"
      install -m 600 "$backup_stamp/$(basename "$SING_BOX_CONFIG")" "$SING_BOX_CONFIG"
    fi
    ((update_argo)) && install -m 755 "$backup_stamp/cloudflared" "$BIN_DIR/cloudflared"
    systemctl restart "${services[@]}" || true
    wait_for_services || true
    die "组件已回滚到更新前版本，请查看 journalctl。"
  fi
}

manage_bbr() {
  local answer
  require_root
  command -v curl >/dev/null 2>&1 || die "缺少 curl，无法启动 BBR/内核管理脚本。"
  brand "${PROJECT_NAME} · BBR / DD" cancel
  section "风险提示"
  yellow "第三方脚本：Linux-NetSpeed"
  menu_hint "可能修改 Linux 内核、BBR 与系统磁盘。"
  read_input "确认启动第三方脚本？[Y/n]：" answer
  is_exit_input "$answer" && { return_notice; return 0; }
  is_confirmed "$answer" || { yellow "已取消启动第三方脚本。"; return 0; }
  info "正在启动第三方脚本..."
  bash <(curl -fsSL --retry 3 --connect-timeout 10 \
    https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh)
}

restart_services() {
  require_root
  load_env
  brand "${PROJECT_NAME} · 服务重启"
  subsection "重启范围"
  key_value "重启服务" "Nginx · $(core_label) · Argo Tunnel"
  info "正在重启全部服务..."
  systemctl daemon-reload
  systemctl restart nginx "$CORE_SERVICE" "$ARGO_SERVICE"
  green "全部服务已重启。"
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
  local command_link target answer resolved_work_dir remove_nginx=0 remove_warp=0 remove_tools=0
  require_root
  [[ -f "$MANAGED_FILE" ]] || die "缺少项目所有权标记，拒绝自动卸载；请人工核对 ${WORK_DIR}。"
  resolved_work_dir="$(readlink -f "$WORK_DIR" 2>/dev/null || true)"
  [[ "$resolved_work_dir" == "$WORK_DIR" ]] ||
    die "项目目录解析结果异常，拒绝递归删除：${WORK_DIR}"
  brand "${PROJECT_NAME} · 项目卸载" cancel
  section "将移除"
  menu_hint "AGS systemd 服务"
  menu_hint "Sing-box / cloudflared"
  menu_hint "${WORK_DIR} 配置与订阅"
  menu_hint "${COMMAND_NAME} / ${COMMAND_NAME_UPPER} 命令入口"
  read_input "确认卸载 AGS？[Y/n]：" answer
  is_exit_input "$answer" && { return_notice; return 0; }
  is_confirmed "$answer" || { yellow "已取消卸载。"; return 0; }
  if command -v nginx >/dev/null 2>&1 ||
    dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -q 'install ok installed'; then
    read_input "确认同时卸载 Nginx？可能被其他网站使用 [Y/n]：" answer
    is_exit_input "$answer" && { return_notice; return 0; }
    is_confirmed "$answer" && remove_nginx=1
  fi
  if command -v warp-cli >/dev/null 2>&1 ||
    dpkg-query -W -f='${Status}' cloudflare-warp 2>/dev/null | grep -q 'install ok installed' ||
    [[ -e /etc/apt/sources.list.d/cloudflare-client.list ||
      -e /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg ]]; then
    read_input "确认同时卸载 Cloudflare WARP 客户端、注册与软件源？[Y/n]：" answer
    is_exit_input "$answer" && { return_notice; return 0; }
    is_confirmed "$answer" && remove_warp=1
  fi
  read_input "确认同时卸载 curl 等通用工具？可能被其他程序使用 [Y/n]：" answer
  is_exit_input "$answer" && { return_notice; return 0; }
  is_confirmed "$answer" && remove_tools=1

  systemctl disable --now "${TRAFFIC_TIMER}.timer" "$TRAFFIC_SERVICE" "$CORE_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
  rm -f "/etc/systemd/system/${CORE_SERVICE}.service" "/etc/systemd/system/${ARGO_SERVICE}.service" \
    "/etc/systemd/system/${TRAFFIC_SERVICE}.service" "/etc/systemd/system/${TRAFFIC_TIMER}.timer"
  remove_legacy_services
  rm -f "$NGINX_CONFIG" "$LEGACY_NGINX_CONFIG" "$OLDER_NGINX_CONFIG" "$NODES_FILE" "$LEGACY_NODES_FILE"
  for command_link in "/usr/local/bin/${COMMAND_NAME}" "/usr/local/bin/${COMMAND_NAME_UPPER}" \
    /usr/local/bin/asb /usr/local/bin/ASB; do
    [[ -L "$command_link" ]] || continue
    target="$(readlink -f "$command_link" 2>/dev/null || true)"
    [[ "$target" == "$LOCAL_SCRIPT" ]] && rm -f "$command_link"
  done
  remove_legacy_symlink
  rm -f "$ENV_FILE" "$NODES_CONFIG" "$SING_BOX_CONFIG" "$LOCAL_SCRIPT" "$MANAGED_FILE" \
    "$SUB_FILE" "$SUB_BASE64_FILE" "$SUB_CLASH_FILE" \
    "$SUB_SING_BOX_FILE" "$SUB_AUTO_QR_FILE" \
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
    purge_installed_packages curl ca-certificates openssl tar unzip qrencode jq sqlite3 gnupg >/dev/null 2>&1 ||
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
    subsection "运行状态"
    state_value "Argo Tunnel" "$(service_status "$ARGO_SERVICE")"
    state_value "代理核心" "$(service_status "$CORE_SERVICE") · $(core_label)"
    state_value "WARP 分流" "$(warp_status)"
    state_value "多路复用" "已启用 · h2mux"
    state_value "TCP Brutal" "$(tcp_brutal_status)"
    key_value "节点概览" "$(node_overview)"
    if [[ -n "$ARGO_DOMAIN" ]]; then
      key_value "Argo 域名" "$ARGO_DOMAIN"
      endpoint_value "优选入口" "$SERVER" "$SERVER_PORT"
      key_value "Argo 回源" "127.0.0.1:${ORIGIN_PORT}"
    fi
    key_value "组件版本" "$(component_versions)"
    ui_line
    brand "${PROJECT_NAME} · 控制中心" main
    UI_TIGHT_SECTION=1
    section "日常管理"
    menu_item 1 "节点订阅" "${COMMAND_NAME} -n"
    menu_item 2 "服务启停" "${COMMAND_NAME} -a"
    menu_item 3 "参数配置" "${COMMAND_NAME} -c"
    menu_item 4 "流量统计" "${COMMAND_NAME} -t"
    menu_item 5 "运行诊断" "${COMMAND_NAME} -x"
    section "系统维护"
    menu_item 6 "项目安装" "${COMMAND_NAME} -i"
    menu_item 7 "组件更新" "${COMMAND_NAME} -v"
    menu_item 8 "备份恢复" "${COMMAND_NAME} -k"
    menu_item 9 "BBR / DD" "${COMMAND_NAME} -b"
    menu_item 10 "项目卸载" "${COMMAND_NAME} -u"
    menu_item 0 "退出脚本"
    ui_line
    read_choice "请选择："; choice="$REPLY"
    case "$choice" in
      1) show_nodes ;;
      2) manage_services ;;
      3) manage_config ;;
      4) traffic_statistics_menu ;;
      5) doctor ;;
      6) install_menu ;;
      7) sync_versions ;;
      8) backup_restore_menu ;;
      9) manage_bbr ;;
      10) uninstall_project ;;
      0) exit 0 ;;
      *) yellow "请输入 0 到 10。" ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    -n) show_nodes ;;
    -a) manage_services ;;
    -c) manage_config ;;
    -t) traffic_statistics_menu ;;
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
    -k)
      [[ -z "${2:-}" ]] || die "-k 仅打开节点备份与恢复菜单，不接受文件路径参数。"
      backup_restore_menu
      ;;
    -b) manage_bbr ;;
    -u) uninstall_project ;;
    --traffic-collect) traffic_collect ;;
    "") menu ;;
    *) die "未知参数。可用参数：-n、-a、-c、-t、-x、-i、-v、-k、-b、-u。" ;;
  esac
fi
