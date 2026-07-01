#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="2.3.0"
PROJECT_NAME="Argo-Singbox"
COMMAND_NAME="asb"
WORK_DIR="/etc/sba"
ENV_FILE="${WORK_DIR}/sba.env"
SING_BOX_CONFIG="${WORK_DIR}/sing-box.json"
NGINX_CONFIG="/etc/nginx/conf.d/sba.conf"
NODES_FILE="/root/sba_nodes.txt"
LOCAL_SCRIPT="${WORK_DIR}/argo-singbox.sh"
BIN_DIR="${WORK_DIR}/bin"
BACKUP_DIR="${WORK_DIR}/backup"
MANAGED_FILE="${WORK_DIR}/managed"
SUB_FILE="${WORK_DIR}/subscription.txt"
SUB_BASE64_FILE="${WORK_DIR}/subscription.base64"
SING_SERVICE="sba-sing-box"
ARGO_SERVICE="sba-cloudflared"

DEFAULT_SERVER="skk.moe"
DEFAULT_SERVER_PORT="443"
DEFAULT_SING_BOX_VERSION="1.13.0-rc.4"
SING_BOX_FORCE_VERSION_URL="https://raw.githubusercontent.com/fscarmen/sing-box/refs/heads/main/force_version"

VLESS_PORT=3011
VMESS_PORT=3012
TROJAN_PORT=3013
VLESS2_PORT=3015
ORIGIN_PORT=3010

green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*" >&2; }
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
EOF
  umask "$old_umask"
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
  cat >"$SING_BOX_CONFIG" <<EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-path1",
      "listen": "127.0.0.1",
      "listen_port": ${VLESS_PORT},
      "users": [{"uuid": "${UUID}"}],
      "transport": {
        "type": "ws",
        "path": "/sba-vl",
        "max_early_data": 2560,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      },
      "multiplex": {"enabled": true, "padding": true}
    },
    {
      "type": "vless",
      "tag": "vless-path2",
      "listen": "127.0.0.1",
      "listen_port": ${VLESS2_PORT},
      "users": [{"uuid": "${UUID}"}],
      "transport": {
        "type": "ws",
        "path": "/sba-vl2",
        "max_early_data": 2560,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      },
      "multiplex": {"enabled": true, "padding": true}
    },
    {
      "type": "vmess",
      "tag": "vmess",
      "listen": "127.0.0.1",
      "listen_port": ${VMESS_PORT},
      "users": [{"uuid": "${UUID}", "alterId": 0}],
      "transport": {
        "type": "ws",
        "path": "/sba-vm",
        "max_early_data": 2560,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      },
      "multiplex": {"enabled": true, "padding": true}
    },
    {
      "type": "trojan",
      "tag": "trojan",
      "listen": "127.0.0.1",
      "listen_port": ${TROJAN_PORT},
      "users": [{"password": "${UUID}"}],
      "transport": {
        "type": "ws",
        "path": "/sba-tr",
        "max_early_data": 2560,
        "early_data_header_name": "Sec-WebSocket-Protocol"
      },
      "multiplex": {"enabled": true, "padding": true}
    }
  ],
  "outbounds": [{"type": "direct", "tag": "direct"}]
}
EOF
  "$BIN_DIR/sing-box" check -c "$SING_BOX_CONFIG"
}

write_nginx_config() {
  cat >"$NGINX_CONFIG" <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 127.0.0.1:${ORIGIN_PORT};
    server_name ${ARGO_DOMAIN};

    location = /sba-vl {
        if (\$http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:${VLESS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
        proxy_redirect off;
    }
    location = /sba-vl2 {
        if (\$http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:${VLESS2_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
        proxy_redirect off;
    }
    location = /sba-vm {
        if (\$http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:${VMESS_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
        proxy_redirect off;
    }
    location = /sba-tr {
        if (\$http_upgrade != "websocket") { return 404; }
        proxy_pass http://127.0.0.1:${TROJAN_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$host;
        proxy_redirect off;
    }
    location = /sba-sub {
        default_type text/plain;
        alias ${SUB_FILE};
    }
    location = /sba-sub-base64 {
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
Description=SBA sing-box
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
Description=SBA Cloudflare 固定隧道
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
  local old_umask vmess_json vmess_link
  vmess_json="{ \"v\": \"2\", \"ps\": \"GreenCloud-Vm\", \"add\": \"${SERVER}\", \"port\": \"${SERVER_PORT}\", \"id\": \"${UUID}\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"${ARGO_DOMAIN}\", \"path\": \"/sba-vm?ed=2560\", \"tls\": \"tls\", \"sni\": \"${ARGO_DOMAIN}\", \"alpn\": \"\" }"
  vmess_link="$(printf '%s' "$vmess_json" | base64 -w 0)"

  old_umask="$(umask)"
  umask 077
  cat >"$NODES_FILE" <<EOF
vless://${UUID}@${SERVER}:${SERVER_PORT}?encryption=none&security=tls&sni=${ARGO_DOMAIN}&type=ws&host=${ARGO_DOMAIN}&path=%2Fsba-vl%3Fed%3D2560#GreenCloud-Vl
vmess://${vmess_link}
trojan://${UUID}@${SERVER}:${SERVER_PORT}?security=tls&sni=${ARGO_DOMAIN}&type=ws&host=${ARGO_DOMAIN}&path=%2Fsba-tr%3Fed%3D2560#GreenCloud-Tr
vless://${UUID}@${SERVER}:${SERVER_PORT}?encryption=none&security=tls&sni=${ARGO_DOMAIN}&type=ws&host=${ARGO_DOMAIN}&path=%2Fsba-vl2%3Fed%3D2560#GreenCloud-Vl-Path2
EOF
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
  local failed=0 public_code public_headers port path
  for service in nginx "$SING_SERVICE" "$ARGO_SERVICE"; do
    if systemctl is-active --quiet "$service"; then
      green "${service}：运行正常"
    else
      red "${service}：运行失败"
      systemctl --no-pager --full status "$service" || true
      failed=1
    fi
  done

  for port in "$ORIGIN_PORT" "$VLESS_PORT" "$VLESS2_PORT" "$VMESS_PORT" "$TROJAN_PORT"; do
    if ! ss -lnt | grep -q "127.0.0.1:${port} "; then
      red "本地端口 ${port} 未监听。"
      failed=1
    fi
  done

  for path in sba-vl sba-vl2 sba-vm sba-tr; do
    public_headers="$(curl -ksS --http1.1 --max-time 8 -D - -o /dev/null \
      --connect-to "${ARGO_DOMAIN}:${SERVER_PORT}:${SERVER}:${SERVER_PORT}" \
      -H "Connection: Upgrade" -H "Upgrade: websocket" \
      -H "Sec-WebSocket-Version: 13" \
      -H "Sec-WebSocket-Key: SGVsbG9Xb3JsZDEyMzQ1Ng==" \
      "https://${ARGO_DOMAIN}:${SERVER_PORT}/${path}" || true)"
    public_code="$(awk '/^HTTP/{code=$2} END{print code}' <<<"$public_headers")"
    if grep -qi '^cf-mitigated: *challenge' <<<"$public_headers"; then
      red "/${path}：Cloudflare 人机挑战（HTTP ${public_code:-403}）"
      failed=1
    elif [[ "$public_code" == "101" ]]; then
      green "/${path}：公网 WebSocket 握手正常"
    else
      red "/${path}：公网 WebSocket 握手失败（HTTP ${public_code:-000}）"
      failed=1
    fi
  done
  [[ "$failed" -eq 0 ]] || yellow "请确认 Public Hostname 指向 http://localhost:${ORIGIN_PORT}，并跳过四个代理路径的 Challenge/WAF。"

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
    if [[ -e "$marker" ]] && ! grep -q "^Description=SBA " "$marker"; then
      die "检测到非本项目服务 ${unit}.service，安装已停止，未覆盖现有服务。"
    fi
  done
  for unit in sing-box cloudflared; do
    marker="/etc/systemd/system/${unit}.service"
    [[ -e "$marker" ]] || continue
    if grep -q "^Description=SBA " "$marker"; then
      yellow "检测到本项目旧版 ${unit}.service，将迁移为项目专属服务名。"
      systemctl disable --now "$unit" 2>/dev/null || true
      rm -f "$marker"
    else
      die "检测到现有 ${unit}.service 且不属于本项目。为避免服务冲突，安装已停止。"
    fi
  done
}

install_sba() {
  local installer_source work_backup sing_stage argo_stage
  require_root
  load_env
  prompt_install_values
  installer_source="$(mktemp)"
  install -m 755 "$0" "$installer_source"
  detect_arch
  install_dependencies
  assert_service_names_available
  install -d -m 755 "$WORK_DIR" "$BIN_DIR"
  install -d -m 700 "$BACKUP_DIR"
  work_backup="${BACKUP_DIR}/config-$(date +%Y%m%d-%H%M%S)"
  install -d -m 700 "$work_backup"
  for file in "$ENV_FILE" "$SING_BOX_CONFIG" "$LOCAL_SCRIPT"; do
    [[ -f "$file" ]] && cp -a "$file" "$work_backup/"
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
  write_nginx_config
  write_services
  create_local_command "$installer_source"
  rm -f "$installer_source"
  systemctl daemon-reload
  systemctl enable nginx "$SING_SERVICE" "$ARGO_SERVICE"
  systemctl restart nginx "$SING_SERVICE" "$ARGO_SERVICE"
  wait_for_services || true
  sync_argo_domain
  generate_nodes
  if health_check; then
    green "SBA 安装 / 更新完成，核心链路检查通过。节点文件：${NODES_FILE}"
  else
    yellow "SBA 文件已安装，但健康检查未全部通过；请先处理上述错误再使用节点。"
  fi
  cat "$NODES_FILE"
}

change_token() {
  require_root
  load_env
  [[ -f "$ENV_FILE" ]] || die "SBA 尚未安装。"
  read -rp "请输入新的 Argo Token: " ARGO_TOKEN
  [[ -n "$ARGO_TOKEN" ]] || die "Argo Token 不能为空。"
  save_env
  write_services
  systemctl daemon-reload
  systemctl restart "$ARGO_SERVICE"
  wait_for_services || true
  sync_argo_domain
  generate_nodes
  if health_check; then
    green "Argo Token 已更新，节点与运行状态已同步。"
  else
    yellow "Argo Token 已更新，但链路检查未全部通过。"
  fi
}

change_server() {
  local endpoint
  require_root
  load_env
  [[ -f "$ENV_FILE" ]] || die "SBA 尚未安装。"
  read -rp "请输入新的 Cloudflare 优选入口 域名/IP:端口 [${SERVER}:${SERVER_PORT}]: " endpoint
  [[ -z "$endpoint" ]] && return 0
  parse_endpoint "$endpoint"
  save_env
  generate_nodes
  if health_check; then
    green "Cloudflare 优选入口已更新，节点与运行状态已同步。"
  else
    yellow "Cloudflare 优选入口已更新，但链路检查未全部通过。"
  fi
}

show_nodes() {
  local node index=0
  load_env
  [[ -f "$NODES_FILE" ]] || die "节点文件不存在，请先安装。"
  printf '原始订阅：https://%s/sba-sub\nBase64 订阅：https://%s/sba-sub-base64\n\n' "$ARGO_DOMAIN" "$ARGO_DOMAIN"
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
  bash <(curl -fsSL --retry 3 --connect-timeout 10 \
    https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh)
}

show_status() {
  local ip memory service port state
  load_env
  ip="$(curl -4fsS --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')"
  memory="$(free -m | awk '/^Mem:/{printf "%s/%s MiB (%.0f%%)",$3,$2,$3*100/$2}')"
  printf '%-14s %s\n' "公网 IP" "${ip:-未知}" "脚本版本" "v${VERSION}" \
    "Sing-box" "$(local_sing_box_version || echo 未安装)" \
    "Cloudflared" "$(local_cloudflared_version || echo 未安装)" \
    "内存" "${memory:-未知}" "优选入口" "${SERVER:-未知}:${SERVER_PORT:-未知}"
  printf '\n服务健康：\n'
  for service in nginx "$SING_SERVICE" "$ARGO_SERVICE"; do
    state="$(systemctl is-active "$service" 2>/dev/null || true)"
    printf '  %-20s %s\n' "$service" "${state:-unknown}"
  done
  printf '\n监听端口：\n'
  for port in "$ORIGIN_PORT" "$VLESS_PORT" "$VLESS2_PORT" "$VMESS_PORT" "$TROJAN_PORT"; do
    ss -lntH "sport = :${port}" | grep -q . && state="LISTEN" || state="CLOSED"
    printf '  %-6s %s\n' "$port" "$state"
  done
  printf '\n最近错误：\n'
  journalctl -u "$SING_SERVICE" -u "$ARGO_SERVICE" -p warning -n 8 --no-pager -o cat 2>/dev/null || true
}

restart_services() {
  require_root
  systemctl restart nginx "$SING_SERVICE" "$ARGO_SERVICE"
  green "服务已重启。"
}

uninstall_sba() {
  require_root
  [[ -f "$MANAGED_FILE" ]] || die "缺少项目所有权标记，拒绝自动卸载；请人工核对 ${WORK_DIR}。"
  systemctl disable --now "$SING_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
  rm -f "/etc/systemd/system/${SING_SERVICE}.service" "/etc/systemd/system/${ARGO_SERVICE}.service"
  rm -f "$NGINX_CONFIG" "/usr/local/bin/${COMMAND_NAME}" "$NODES_FILE"
  rm -rf "$WORK_DIR"
  systemctl daemon-reload
  systemctl restart nginx 2>/dev/null || true
  green "SBA 已卸载。"
}

menu() {
  while true; do
    cat <<EOF

${PROJECT_NAME} v${VERSION}
1. 查看节点信息 (${COMMAND_NAME} -n)
2. 开启/关闭 Argo (${COMMAND_NAME} -a)
3. 开启/关闭 Sing-box (${COMMAND_NAME} -s)
4. 更换 Argo 隧道 Token (${COMMAND_NAME} -t)
5. 更换优选域名、IP 或端口 (${COMMAND_NAME} -d)
6. 同步 Argo 和 Sing-box 至最新版本 (${COMMAND_NAME} -v)
7. 卸载 (${COMMAND_NAME} -u)
8. 安装 / 更新 ${PROJECT_NAME}
9. 查看简洁诊断
10. 重启服务
0. 退出
EOF
    read -rp "请选择: " choice
    case "$choice" in
      1) show_nodes ;;
      2) toggle_service "$ARGO_SERVICE" Argo ;;
      3) toggle_service "$SING_SERVICE" Sing-box ;;
      4) change_token ;;
      5) change_server ;;
      6) sync_versions ;;
      7) uninstall_sba ;;
      8) install_sba ;;
      9) show_status ;;
      10) restart_services ;;
      0) exit 0 ;;
      *) yellow "请输入 0 到 10。" ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    -n) show_nodes ;;
    -a) toggle_service "$ARGO_SERVICE" Argo ;;
    -s) toggle_service "$SING_SERVICE" Sing-box ;;
    -t) change_token ;;
    -d) change_server ;;
    -v) sync_versions ;;
    -b) yellow "外部工具：即将执行 ylx2016/Linux-NetSpeed 远程脚本，本项目不维护其内容。"; manage_bbr ;;
    -u) uninstall_sba ;;
    install) install_sba ;;
    token) change_token ;;
    server) change_server ;;
    status) show_status ;;
    nodes) show_nodes ;;
    restart) restart_services ;;
    uninstall) uninstall_sba ;;
    "") menu ;;
    *) die "未知参数。可用参数：-n、-a、-s、-t、-d、-v、-b、-u、install、token、server、status、nodes、restart、uninstall。" ;;
  esac
fi
