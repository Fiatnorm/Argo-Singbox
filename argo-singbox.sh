#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="2.8.0"
PROJECT_NAME="Argo-Singbox"
COMMAND_NAME="asb"
WORK_DIR="/etc/asb"
WORK_DIR_NAME="${WORK_DIR##*/}"
LEGACY_WORK_DIR="/etc/sba"
ENV_FILE="${WORK_DIR}/asb.env"
SING_BOX_CONFIG="${WORK_DIR}/sing-box.json"
NGINX_CONFIG="/etc/nginx/conf.d/argo-singbox.conf"
LEGACY_NGINX_CONFIG="/etc/nginx/conf.d/sba.conf"
NODES_FILE="/root/argo-singbox_nodes.txt"
LEGACY_NODES_FILE="/root/sba_nodes.txt"
LOCAL_SCRIPT="${WORK_DIR}/argo-singbox.sh"
BIN_DIR="${WORK_DIR}/bin"
BACKUP_DIR="${WORK_DIR}/backup"
MANAGED_FILE="${WORK_DIR}/managed"
NODES_CONFIG="${WORK_DIR}/nodes.conf"
SUB_FILE="${WORK_DIR}/subscription.txt"
SUB_BASE64_FILE="${WORK_DIR}/subscription.base64"
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
green() { printf '%s✓ %s%s\n' "$C_BRIGHT_GREEN" "$*" "$C_RESET"; }
yellow() { printf '%s! %s%s\n' "$C_BRIGHT_YELLOW" "$*" "$C_RESET"; }
red() { printf '%s✗ %s%s\n' "$C_BRIGHT_RED" "$*" "$C_RESET" >&2; }
info() { printf '%s• %s%s\n' "$C_BRIGHT_CYAN" "$*" "$C_RESET"; }
section() { printf '\n%s%s%s%s\n' "$C_BOLD" "$C_BRIGHT_BLUE" "$*" "$C_RESET"; }
prompt() { printf '%s› %s%s' "$C_BRIGHT_MAGENTA" "$*" "$C_RESET"; }
menu_item() {
  printf '%s%2s%s  %s%s%s%s%s%s\n' "$C_BRIGHT_CYAN" "$1" "$C_RESET" "$C_WHITE" "$2" \
    "$C_RESET" "$C_DIM" "${3:+  [$3]}" "$C_RESET"
}
die() { red "$*"; exit 1; }

require_root() {
  [[ ${EUID} -eq 0 ]] || die "请使用 root 用户运行此脚本。"
  command -v systemctl >/dev/null 2>&1 || die "当前系统不支持 systemd。"
  [[ -r /etc/os-release ]] || die "无法识别系统，仅支持 Debian/Ubuntu。"
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ "${ID:-}" == "debian" || "${ID:-}" == "ubuntu" ]] ||
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
  local old_umask
  old_umask="$(umask)"
  install -d -m 755 "$WORK_DIR"
  umask 077
  cat >"$ENV_FILE" <<EOF
UUID='${UUID}'
ARGO_DOMAIN='${ARGO_DOMAIN}'
SERVER='${SERVER}'
SERVER_PORT='${SERVER_PORT}'
ARGO_TOKEN='${ARGO_TOKEN}'
ORIGIN_PORT='${ORIGIN_PORT}'
WARP_ENABLED='${WARP_ENABLED}'
WARP_PROXY_PORT='${WARP_PROXY_PORT}'
WARP_DOMAINS='${WARP_DOMAINS}'
EOF
  umask "$old_umask"
}

valid_uuid() { [[ "${1,,}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; }
valid_path() { [[ "$1" =~ ^/[A-Za-z0-9._~-]+$ ]]; }
valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && ((10#$1 >= 1 && 10#$1 <= 65535)); }

normalize_warp_domains() {
  local input="$1" item host output="" old_ifs="$IFS"
  IFS=','
  for item in $input; do
    item="${item//[[:space:]]/}"
    [[ -n "$item" ]] || continue
    host="${item#*://}"; host="${host%%/*}"; host="${host%%:*}"
    host="${host#.}"
    [[ "$host" =~ ^([A-Za-z0-9-]+\.)*[A-Za-z0-9-]+$ ]] ||
      die "WARP 目标网址无效：${item}"
    output+="${output:+,}${host,,}"
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
vless-1|vless|/argo-vl|$((ORIGIN_PORT + 1))|
vmess-1|vmess|/argo-vm|$((ORIGIN_PORT + 2))|
trojan-1|trojan|/argo-tr|$((ORIGIN_PORT + 3))|
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
    if curl -fL --retry 3 --retry-all-errors --connect-timeout 10 --max-time 180 \
      "$candidate" -o "${output}.part"; then
      [[ -s "${output}.part" ]] || continue
      mv -f "${output}.part" "$output"
      return 0
    fi
    rm -f "${output}.part"
  done
  die "下载失败（已尝试直连和 GitHub 代理）：${url}"
}

install_dependencies() {
  command -v apt-get >/dev/null 2>&1 || die "轻量版仅支持使用 apt 的 Debian/Ubuntu。"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates nginx openssl tar qrencode
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
      vless) printf '"users":[{"uuid":"%s"}],' "$UUID" >>"$SING_BOX_CONFIG" ;;
    esac
    printf '"transport":{"type":"ws","path":"%s","max_early_data":2560,"early_data_header_name":"Sec-WebSocket-Protocol"},"multiplex":{"enabled":true,"padding":true}}' "$path" >>"$SING_BOX_CONFIG"
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
        default_type text/plain;
        alias ${SUB_BASE64_FILE};
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
}

generate_nodes() {
  local old_umask vmess_json vmess_link tag protocol path port socks encoded_path
  ensure_nodes_config
  validate_nodes_config
  old_umask="$(umask)"
  umask 077
  : >"$NODES_FILE"
  while IFS='|' read -r tag protocol path port socks; do
    encoded_path="%2F${path#/}%3Fed%3D2560"
    case "$protocol" in
      vless) printf 'vless://%s@%s:%s?encryption=none&security=tls&sni=%s&type=ws&host=%s&path=%s#%s\n' \
        "$UUID" "$SERVER" "$SERVER_PORT" "$ARGO_DOMAIN" "$ARGO_DOMAIN" "$encoded_path" "$tag" >>"$NODES_FILE" ;;
      trojan) printf 'trojan://%s@%s:%s?security=tls&sni=%s&type=ws&host=%s&path=%s#%s\n' \
        "$UUID" "$SERVER" "$SERVER_PORT" "$ARGO_DOMAIN" "$ARGO_DOMAIN" "$encoded_path" "$tag" >>"$NODES_FILE" ;;
      vmess)
        vmess_json="{\"v\":\"2\",\"ps\":\"${tag}\",\"add\":\"${SERVER}\",\"port\":\"${SERVER_PORT}\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${ARGO_DOMAIN}\",\"path\":\"${path}?ed=2560\",\"tls\":\"tls\",\"sni\":\"${ARGO_DOMAIN}\",\"alpn\":\"\"}"
        vmess_link="$(printf '%s' "$vmess_json" | base64 -w 0)"
        printf 'vmess://%s\n' "$vmess_link" >>"$NODES_FILE" ;;
    esac
  done <"$NODES_CONFIG"
  chmod 600 "$NODES_FILE"
  install -m 644 "$NODES_FILE" "$SUB_FILE"
  base64 -w 0 "$NODES_FILE" >"$SUB_BASE64_FILE"
  chmod 644 "$SUB_BASE64_FILE"
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
    yellow "未能从 cloudflared 日志读取实际域名，请确认输入域名与 Tunnel Public Hostname 完全一致。"
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
  local failed=0 public_code public_headers port path tag protocol socks
  ensure_nodes_config
  for service in nginx "$SING_SERVICE" "$ARGO_SERVICE"; do
    if systemctl is-active --quiet "$service"; then
      green "${service}：运行正常"
    else
      red "${service}：运行失败"
      systemctl --no-pager --full status "$service" || true
      failed=1
    fi
  done

  while read -r port; do
    if ! ss -lnt | grep -q "127.0.0.1:${port} "; then
      red "本地端口 ${port} 未监听。"
      failed=1
    fi
  done < <(printf '%s\n' "$ORIGIN_PORT"; cut -d'|' -f4 "$NODES_CONFIG")

  while IFS='|' read -r tag protocol path port socks; do
    public_headers="$(curl -ksS --http1.1 --max-time 8 -D - -o /dev/null \
      --connect-to "${ARGO_DOMAIN}:${SERVER_PORT}:${SERVER}:${SERVER_PORT}" \
      -H "Connection: Upgrade" -H "Upgrade: websocket" \
      -H "Sec-WebSocket-Version: 13" \
      -H "Sec-WebSocket-Key: SGVsbG9Xb3JsZDEyMzQ1Ng==" \
      "https://${ARGO_DOMAIN}:${SERVER_PORT}${path}" || true)"
    public_code="$(awk '/^HTTP/{code=$2} END{print code}' <<<"$public_headers")"
    if grep -qi '^cf-mitigated: *challenge' <<<"$public_headers"; then
      red "${path}：Cloudflare 人机挑战（HTTP ${public_code:-403}）"
      failed=1
    elif [[ "$public_code" == "101" ]]; then
      green "${path}：公网 WebSocket 握手正常"
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
  read -rp "请输入 Argo Token（必填）: " value
  [[ -n "$value" ]] || die "Argo Token 不能为空。"
  ARGO_TOKEN="$value"
  read -rp "请输入 Argo 域名（必填）${ARGO_DOMAIN:+ [${ARGO_DOMAIN}]}: " value
  ARGO_DOMAIN="${value:-$ARGO_DOMAIN}"
  [[ -n "$ARGO_DOMAIN" ]] || die "Argo 域名不能为空。"
  [[ -n "$UUID" ]] || UUID="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || true)"
  [[ -n "$UUID" ]] || UUID="$(openssl rand -hex 16 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\)$/\1-\2-\3-\4-\5/')"
  read -rp "请输入 UUID [${UUID}]: " value
  UUID="${value:-$UUID}"
  [[ "${UUID,,}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]] ||
    die "UUID 格式不正确。"
  read -rp "请输入 Cloudflare 优选入口 域名/IP:端口 [${SERVER}:${SERVER_PORT}]: " endpoint
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
  ((port >= 1 && port <= 65535)) || die "端口必须是 1 到 65535。"
  SERVER="$host"
  SERVER_PORT="$port"
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

install_project() {
  local installer_source work_backup="" sing_stage argo_stage file
  require_root
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
  stage_sing_box "" "$sing_stage"
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
  if ((LEGACY_MIGRATED)); then
    systemctl stop "$LEGACY_SING_SERVICE" "$LEGACY_ARGO_SERVICE" 2>/dev/null || true
  fi
  systemctl restart nginx "$SING_SERVICE" "$ARGO_SERVICE"
  if wait_for_services; then
    remove_legacy_services
    remove_legacy_symlink
  else
    yellow "新服务尚未全部启动，已保留旧服务文件以便排查。"
    if ((LEGACY_MIGRATED)); then
      systemctl restart "$LEGACY_SING_SERVICE" "$LEGACY_ARGO_SERVICE" 2>/dev/null || true
    fi
  fi
  systemctl daemon-reload
  sync_argo_domain
  generate_nodes
  rm -f "$LEGACY_NODES_FILE"
  if health_check; then
    green "${PROJECT_NAME} 安装 / 更新完成，核心链路检查通过。节点文件：${NODES_FILE}"
  else
    yellow "${PROJECT_NAME} 文件已安装，但健康检查未全部通过；请先处理上述错误再使用节点。"
  fi
  cat "$NODES_FILE"
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
  [[ -f "$snapshot/${SING_SERVICE}.service" ]] && install -m 644 "$snapshot/${SING_SERVICE}.service" "/etc/systemd/system/${SING_SERVICE}.service"
  [[ -f "$snapshot/${ARGO_SERVICE}.service" ]] && install -m 644 "$snapshot/${ARGO_SERVICE}.service" "/etc/systemd/system/${ARGO_SERVICE}.service"
  rm -rf "$snapshot"
  systemctl daemon-reload
  systemctl restart nginx "$SING_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
  die "配置未生效，已恢复修改前文件。"
}

list_node_profiles() {
  local tag protocol path port socks
  printf '%-18s %-8s %-20s %-7s %s\n' "标签" "协议" "WS 路径" "端口" "出站"
  while IFS='|' read -r tag protocol path port socks; do
    printf '%-18s %-8s %-20s %-7s %s\n' "$tag" "$protocol" "$path" "$port" "${socks:-direct}"
  done <"$NODES_CONFIG"
}

add_node_profile() {
  local tag protocol path port socks default_port
  begin_config_change
  default_port="$(next_node_port)"
  read -rp "节点标签（字母/数字/_/-）: " tag
  read -rp "协议（vless/vmess/trojan）: " protocol
  protocol="${protocol,,}"
  read -rp "WS 路径（以 / 开头）: " path
  read -rp "本地监听端口 [${default_port}]: " port
  port="${port:-$default_port}"
  read -rp "SOCKS5 出站（主机:端口:用户名:密码，留空为直连）: " socks
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
  read -rp "新的 Argo Tunnel 回源端口 [${ORIGIN_PORT}]: " value
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
  read -rp "要删除的节点标签: " tag
  grep -Fq "${tag}|" "$NODES_CONFIG" || die "未找到节点标签：${tag}"
  [[ "$(wc -l <"$NODES_CONFIG")" -gt 1 ]] || die "至少必须保留一个节点。"
  temp="$(mktemp)"
  awk -F'|' -v wanted="$tag" '$1 != wanted' "$NODES_CONFIG" >"$temp"
  install -m 600 "$temp" "$NODES_CONFIG"
  rm -f "$temp"
  apply_runtime_config
}

edit_node_profile() {
  local wanted tag protocol path port socks new_path new_port new_socks temp
  list_node_profiles
  read -rp "要修改的节点标签: " wanted
  while IFS='|' read -r tag protocol path port socks; do
    [[ "$tag" == "$wanted" ]] && break
  done <"$NODES_CONFIG"
  [[ "${tag:-}" == "$wanted" ]] || die "未找到节点标签：${wanted}"
  begin_config_change
  read -rp "新 WS 路径 [${path}]: " new_path
  read -rp "新本地端口 [${port}]: " new_port
  read -rp "新 SOCKS5 [${socks:-direct}]（留空保持，输入 - 改为直连）: " new_socks
  path="${new_path:-$path}"; port="${new_port:-$port}"
  [[ "$new_socks" == "-" ]] && socks="" || socks="${new_socks:-$socks}"
  valid_path "$path" || die "WS 路径格式错误。"
  valid_port "$port" || die "端口格式错误。"
  [[ -z "$socks" ]] || parse_socks5 "$socks" >/dev/null
  ! awk -F'|' -v wanted="$wanted" -v path="$path" -v port="$port" \
    '$1 != wanted && ($3 == path || $4 == port) {found=1} END {exit !found}' "$NODES_CONFIG" ||
    die "WS 路径或端口已被其他节点使用。"
  temp="$(mktemp)"
  awk -F'|' -v OFS='|' -v wanted="$wanted" -v path="$path" -v port="$port" -v socks="$socks" \
    '$1 == wanted {$3=path; $4=port; $5=socks} {print}' "$NODES_CONFIG" >"$temp"
  install -m 600 "$temp" "$NODES_CONFIG"; rm -f "$temp"
  validate_nodes_config
  apply_runtime_config
}

configure_warp() {
  local answer port targets
  printf '当前状态：%s；代理端口：%s；目标：%s\n' \
    "$([[ "$WARP_ENABLED" == "1" ]] && echo 已启用 || echo 未启用)" \
    "$WARP_PROXY_PORT" "${WARP_DOMAINS:-无}"
  read -rp "启用按网址分流到 Cloudflare WARP？[y/N]: " answer
  begin_config_change
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    WARP_ENABLED=0
    WARP_DOMAINS=""
    apply_runtime_config
    return
  fi
  command -v warp-cli >/dev/null 2>&1 ||
    die "未安装官方 Cloudflare WARP 客户端。请先安装 cloudflare-warp 软件包。"
  read -rp "WARP 本地 SOCKS5 端口 [${WARP_PROXY_PORT}]: " port
  port="${port:-$WARP_PROXY_PORT}"
  valid_port "$port" || die "WARP 代理端口无效。"
  read -rp "走 WARP 的网址/域名（逗号分隔）[${WARP_DOMAINS:-无}]: " targets
  targets="${targets:-$WARP_DOMAINS}"
  targets="$(normalize_warp_domains "$targets")"
  systemctl enable --now warp-svc >/dev/null 2>&1 ||
    die "无法启动 warp-svc。"
  warp-cli registration show >/dev/null 2>&1 ||
    warp-cli --accept-tos registration new >/dev/null ||
    die "WARP 客户端注册失败。"
  warp-cli --accept-tos mode proxy >/dev/null &&
    warp-cli --accept-tos proxy port "$port" >/dev/null &&
    warp-cli --accept-tos connect >/dev/null ||
    die "无法把 WARP 客户端切换到本地代理模式，请运行 warp-cli mode --help 检查客户端版本。"
  WARP_ENABLED=1
  WARP_PROXY_PORT="$port"
  WARP_DOMAINS="$targets"
  apply_runtime_config
}

manage_config() {
  local choice value endpoint
  require_root
  load_env
  [[ -f "$ENV_FILE" ]] || die "${PROJECT_NAME} 尚未安装。"
  ensure_nodes_config
  while true; do
    section "基础配置"
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
    read -rp "请选择: " choice
    case "$choice" in
      1)
        begin_config_change
        read -rp "新 Token [留空保持]: " value; ARGO_TOKEN="${value:-$ARGO_TOKEN}"
        read -rp "新 Argo 域名 [${ARGO_DOMAIN}]: " value; ARGO_DOMAIN="${value:-$ARGO_DOMAIN}"
        [[ -n "$ARGO_TOKEN" && "$ARGO_DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || die "Token 或域名无效。"
        apply_runtime_config
        ;;
      2) begin_config_change; read -rp "新优选入口 域名/IP:端口: " endpoint; parse_endpoint "$endpoint"; apply_runtime_config ;;
      3) change_origin_port ;;
      4) begin_config_change; read -rp "新 UUID: " value; valid_uuid "$value" || die "UUID 格式错误。"; UUID="$value"; apply_runtime_config ;;
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
  local output="${1:-/root/asb-backup-$(date +%Y%m%d-%H%M%S).tar.gz}"
  require_root
  [[ -f "$MANAGED_FILE" ]] || die "缺少项目所有权标记，拒绝备份。"
  [[ "$output" == *.tar.gz ]] || die "备份文件必须以 .tar.gz 结尾。"
  tar -C "$(dirname "$WORK_DIR")" -czf "${output}.tmp" "$WORK_DIR_NAME"
  mv -f "${output}.tmp" "$output"
  chmod 600 "$output"
  green "备份完成：${output}"
}

restore_project() {
  local archive="${1:-}" stage old_dir
  require_root
  [[ -n "$archive" ]] || read -rp "请输入备份文件路径: " archive
  [[ -f "$archive" ]] || die "备份文件不存在：${archive}"
  [[ -f "$MANAGED_FILE" ]] || die "当前 ${WORK_DIR} 缺少项目所有权标记，拒绝覆盖。"
  stage="$(mktemp -d)"
  tar -xzf "$archive" -C "$stage"
  [[ -f "$stage/${WORK_DIR_NAME}/managed" && -f "$stage/${WORK_DIR_NAME}/asb.env" &&
    -x "$stage/${WORK_DIR_NAME}/bin/sing-box" && -x "$stage/${WORK_DIR_NAME}/bin/cloudflared" ]] ||
    { rm -rf "$stage"; die "备份结构或所有权标记无效。"; }
  old_dir="${WORK_DIR}.restore-old-$(date +%Y%m%d-%H%M%S)"
  systemctl stop "$SING_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
  mv "$WORK_DIR" "$old_dir"
  if mv "$stage/${WORK_DIR_NAME}" "$WORK_DIR"; then
    rm -rf "$stage"
    load_env
    ensure_nodes_config
    write_sing_box_config
    write_nginx_config
    write_services
    systemctl daemon-reload
    if systemctl restart nginx "$SING_SERVICE" "$ARGO_SERVICE" && wait_for_services; then
      generate_nodes
      rm -rf "$old_dir"
      green "恢复完成：${archive}"
      return 0
    fi
  fi
  red "恢复后验证失败，正在回滚。"
  rm -rf "$WORK_DIR"
  mv "$old_dir" "$WORK_DIR"
  rm -rf "$stage"
  systemctl restart nginx "$SING_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
  die "恢复失败，已回滚到恢复前状态。"
}

doctor() {
  local failed=0 token_in_unit=0 warp_target ip memory
  require_root
  load_env
  ensure_nodes_config
  ip="$(curl -4fsS --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null ||
    hostname -I 2>/dev/null | awk '{print $1}')"
  memory="$(free -m | awk '/^Mem:/{printf "%s/%s MiB (%.0f%%)",$3,$2,$3*100/$2}')"
  printf '公网 IP：%s\n脚本版本：v%s\n内存：%s\n优选入口：%s:%s\nArgo 回源：127.0.0.1:%s\n' \
    "${ip:-未知}" "$VERSION" "${memory:-未知}" "${SERVER:-未知}" "${SERVER_PORT:-未知}" "$ORIGIN_PORT"
  printf '配置文件：'
  if validate_nodes_config && valid_uuid "$UUID" && [[ -n "$ARGO_DOMAIN" && -n "$ARGO_TOKEN" ]]; then green "有效"; else red "无效"; failed=1; fi
  if "$BIN_DIR/sing-box" check -c "$SING_BOX_CONFIG" >/dev/null 2>&1; then green "Sing-box 配置：有效"; else red "Sing-box 配置：无效"; failed=1; fi
  if nginx -t >/dev/null 2>&1; then green "Nginx 配置：有效"; else red "Nginx 配置：无效"; failed=1; fi
  [[ -f "/etc/systemd/system/${ARGO_SERVICE}.service" ]] &&
    grep -Fq -- "--token ${ARGO_TOKEN}" "/etc/systemd/system/${ARGO_SERVICE}.service" && token_in_unit=1
  ((token_in_unit)) && green "Token：已配置且服务文件一致" || { red "Token：缺失或服务文件未同步"; failed=1; }
  printf '脚本 v%s；Sing-box %s；Cloudflared %s\n' "$VERSION" "$(local_sing_box_version || echo 未安装)" "$(local_cloudflared_version || echo 未安装)"
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
  printf '\n最近日志：\n'
  journalctl -u "$SING_SERVICE" -u "$ARGO_SERVICE" -n 30 --no-pager -o short-iso 2>/dev/null || true
  return "$failed"
}

show_nodes() {
  local node index=0
  load_env
  [[ -f "$NODES_FILE" ]] || die "节点文件不存在，请先安装。"
  printf '原始订阅：https://%s/asb-sub\nBase64 订阅：https://%s/asb-sub-base64\nUUID 订阅：https://%s/%s\n\n' \
    "$ARGO_DOMAIN" "$ARGO_DOMAIN" "$ARGO_DOMAIN" "$UUID"
  while IFS= read -r node; do
    ((index+=1))
    printf '[节点 %d]\n%s\n' "$index" "$node"
    command -v qrencode >/dev/null 2>&1 && qrencode -t ANSIUTF8 "$node"
  done <"$NODES_FILE"
}

toggle_service() {
  local service="$1" label="$2"
  require_root
  systemctl list-unit-files "${service}.service" --no-legend 2>/dev/null | grep -q "^${service}.service" ||
    die "${label} 尚未安装。"
  if systemctl is-active --quiet "$service"; then
    systemctl disable --now "$service"
    green "${label} 已关闭。"
  else
    systemctl enable --now "$service"
    green "${label} 已开启。"
  fi
}

sync_versions() {
  local old_argo old_sing new_argo new_sing wanted_sing wanted_argo
  local sing_stage="" argo_stage="" backup_stamp answer update_sing=0 update_argo=0
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
  printf 'Sing-box：%s → %s\nCloudflared：%s → %s\n' \
    "${old_sing:-未安装}" "${new_sing:-未知}" "${old_argo:-未安装}" "${new_argo:-未知}"
  if [[ "$old_sing" == "$new_sing" && "$old_argo" == "$new_argo" ]]; then
    green "两个核心均已是目标版本，无需更新。"
    return 0
  fi
  read -rp "确认更新需要变更的核心？[y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { yellow "已取消更新。"; return 0; }
  if [[ "$old_sing" != "$new_sing" ]]; then
    update_sing=1
    sing_stage="$(mktemp)"
    stage_sing_box "$wanted_sing" "$sing_stage"
    "$sing_stage" check -c "$SING_BOX_CONFIG"
  fi
  if [[ "$old_argo" != "$new_argo" ]]; then
    update_argo=1
    argo_stage="$(mktemp)"
    stage_cloudflared "$argo_stage"
  fi
  backup_stamp="${BACKUP_DIR}/core-$(date +%Y%m%d-%H%M%S)"
  install -d -m 700 "$backup_stamp"
  cp -a "$BIN_DIR/sing-box" "$BIN_DIR/cloudflared" "$backup_stamp/"
  if ((update_sing)); then
    install -m 755 "$sing_stage" "${BIN_DIR}/sing-box.new"
    mv -f "${BIN_DIR}/sing-box.new" "$BIN_DIR/sing-box"
  fi
  if ((update_argo)); then
    install -m 755 "$argo_stage" "${BIN_DIR}/cloudflared.new"
    mv -f "${BIN_DIR}/cloudflared.new" "$BIN_DIR/cloudflared"
  fi
  rm -f "$sing_stage" "$argo_stage"
  if systemctl restart "$SING_SERVICE" "$ARGO_SERVICE" &&
    wait_for_services && "$BIN_DIR/sing-box" check -c "$SING_BOX_CONFIG"; then
    rm -rf "$backup_stamp"
    green "核心更新成功：Sing-box ${old_sing:-无} → ${new_sing}；Cloudflared ${old_argo:-无} → ${new_argo}"
  else
    red "更新后验证失败，正在自动回滚。"
    install -m 755 "$backup_stamp/sing-box" "$BIN_DIR/sing-box"
    install -m 755 "$backup_stamp/cloudflared" "$BIN_DIR/cloudflared"
    systemctl restart "$SING_SERVICE" "$ARGO_SERVICE" || true
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

uninstall_project() {
  local legacy_link target
  require_root
  [[ -f "$MANAGED_FILE" ]] || die "缺少项目所有权标记，拒绝自动卸载；请人工核对 ${WORK_DIR}。"
  systemctl disable --now "$SING_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
  rm -f "/etc/systemd/system/${SING_SERVICE}.service" "/etc/systemd/system/${ARGO_SERVICE}.service"
  rm -f "$NGINX_CONFIG" "$LEGACY_NGINX_CONFIG" "/usr/local/bin/${COMMAND_NAME}" \
    "$NODES_FILE" "$LEGACY_NODES_FILE"
  for legacy_link in /usr/local/bin/sb /usr/local/bin/argo-singbox; do
    [[ -L "$legacy_link" ]] || continue
    target="$(readlink -f "$legacy_link" 2>/dev/null || true)"
    [[ "$target" == "$LOCAL_SCRIPT" ]] && rm -f "$legacy_link"
  done
  rm -f "$ENV_FILE" "$NODES_CONFIG" "$SING_BOX_CONFIG" "$LOCAL_SCRIPT" "$MANAGED_FILE" \
    "$SUB_FILE" "$SUB_BASE64_FILE" "$BIN_DIR/sing-box" "$BIN_DIR/cloudflared"
  rmdir "$BIN_DIR" "$BACKUP_DIR" "$WORK_DIR" 2>/dev/null || true
  systemctl daemon-reload
  systemctl restart nginx 2>/dev/null || true
  green "${PROJECT_NAME} 已卸载。"
}

menu() {
  while true; do
    section "${PROJECT_NAME} v${VERSION}"
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
    menu_item 9 "备份 ${WORK_DIR}" "${COMMAND_NAME} -k"
    menu_item 10 "恢复 ${WORK_DIR}" "${COMMAND_NAME} -l"
    menu_item 11 "第三方 BBR / DD 工具" "${COMMAND_NAME} -b"
    menu_item 12 "卸载 ${PROJECT_NAME}" "${COMMAND_NAME} -u"
    menu_item 0 "退出"
    read -rp "请选择: " choice
    case "$choice" in
      1) show_nodes ;;
      2) toggle_service "$ARGO_SERVICE" Argo ;;
      3) toggle_service "$SING_SERVICE" Sing-box ;;
      4) manage_config ;;
      5) restart_services ;;
      6) doctor ;;
      7) install_project ;;
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
    -i) install_project ;;
    -v) sync_versions ;;
    -k) backup_project "${2:-}" ;;
    -l) restore_project "${2:-}" ;;
    -b) manage_bbr ;;
    -u) uninstall_project ;;
    "") menu ;;
    *) die "未知参数。可用参数：-n、-a、-s、-c、-r、-x、-i、-v、-k、-l、-b、-u。" ;;
  esac
fi
