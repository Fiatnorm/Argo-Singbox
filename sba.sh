#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="2.2.0"
PROJECT_NAME="Argo-Singbox"
COMMAND_NAME="asb"
WORK_DIR="/etc/sba"
ENV_FILE="${WORK_DIR}/sba.env"
SING_BOX_CONFIG="${WORK_DIR}/sing-box.json"
NGINX_CONFIG="/etc/nginx/conf.d/sba.conf"
NODES_FILE="/root/sba_nodes.txt"
LOCAL_SCRIPT="${WORK_DIR}/argo-singbox.sh"

DEFAULT_UUID="102a8c7b-8360-44ed-85c8-b1da1aecd363"
DEFAULT_DOMAIN="sb.fiatnorm.us.kg"
DEFAULT_SERVER="skk.moe"
DEFAULT_SERVER_PORT="443"
DEFAULT_SING_BOX_VERSION="1.13.0-rc.4"
SBA_FORCE_VERSION_URL="https://raw.githubusercontent.com/fscarmen/sing-box/refs/heads/main/force_version"

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
}

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
  fi
  UUID="${UUID:-$DEFAULT_UUID}"
  ARGO_DOMAIN="${ARGO_DOMAIN:-$DEFAULT_DOMAIN}"
  SERVER="${SERVER:-$DEFAULT_SERVER}"
  SERVER_PORT="${SERVER_PORT:-$DEFAULT_SERVER_PORT}"
  ARGO_TOKEN="${ARGO_TOKEN:-}"
}

save_env() {
  local old_umask
  old_umask="$(umask)"
  install -d -m 700 "$WORK_DIR"
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
  curl -fL --retry 3 --connect-timeout 10 "$url" -o "$output"
}

install_dependencies() {
  command -v apt-get >/dev/null 2>&1 || die "轻量版仅支持使用 apt 的 Debian/Ubuntu。"
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates nginx openssl tar
}

get_sing_box_version() {
  local force_version releases version_family result
  force_version="$(curl -fsSL --connect-timeout 3 "$SBA_FORCE_VERSION_URL" 2>/dev/null |
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

install_sing_box() {
  local version archive
  version="$(get_sing_box_version)"
  [[ -n "$version" ]] || die "无法确定 sing-box 版本。"
  archive="/tmp/sing-box.tar.gz"
  download "https://github.com/SagerNet/sing-box/releases/download/v${version}/sing-box-${version}-linux-${ARCH}.tar.gz" "$archive"
  tar -xzf "$archive" -C /tmp
  install -m 755 "/tmp/sing-box-${version}-linux-${ARCH}/sing-box" /usr/local/bin/sing-box
  rm -rf "$archive" "/tmp/sing-box-${version}-linux-${ARCH}"
}

install_cloudflared() {
  local suffix
  [[ "$ARCH" == "amd64" ]] && suffix="amd64" || suffix="arm64"
  download "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${suffix}" /tmp/cloudflared
  install -m 755 /tmp/cloudflared /usr/local/bin/cloudflared
  rm -f /tmp/cloudflared
}

local_sing_box_version() {
  /usr/local/bin/sing-box version 2>/dev/null | awk '/version/{print $NF; exit}'
}

local_cloudflared_version() {
  /usr/local/bin/cloudflared --version 2>/dev/null |
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
  /usr/local/bin/sing-box check -c "$SING_BOX_CONFIG"
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
    location / { return 404; }
}
EOF
  nginx -t
}

write_services() {
  cat >/etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=SBA sing-box
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${WORK_DIR}
ExecStart=/usr/local/bin/sing-box run -c ${SING_BOX_CONFIG}
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF

  cat >/etc/systemd/system/cloudflared.service <<EOF
[Unit]
Description=SBA Cloudflare 固定隧道
After=network-online.target nginx.service
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/cloudflared tunnel --edge-ip-version auto --no-autoupdate run --token ${ARGO_TOKEN}
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
  active_since="$(systemctl show cloudflared -p ActiveEnterTimestamp --value 2>/dev/null || true)"
  for attempt in {1..10}; do
    if [[ -n "$active_since" ]]; then
      actual_domain="$(journalctl -u cloudflared --since "$active_since" --no-pager -o cat 2>/dev/null |
        sed -n 's/.*"hostname"[^A-Za-z0-9.-]*\([A-Za-z0-9.-]\+\).*/\1/p' | tail -n1)"
    else
      actual_domain="$(journalctl -u cloudflared -n 200 --no-pager -o cat 2>/dev/null |
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
    for service in nginx sing-box cloudflared; do
      systemctl is-active --quiet "$service" || ready=0
    done
    [[ "$ready" -eq 1 ]] && return 0
    sleep 1
  done
  return 1
}

health_check() {
  local failed=0 public_code public_headers port
  for service in nginx sing-box cloudflared; do
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

  public_headers="$(curl -ksS --http1.1 --max-time 5 -D - -o /dev/null \
    --connect-to "${ARGO_DOMAIN}:${SERVER_PORT}:${SERVER}:${SERVER_PORT}" \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: SGVsbG9Xb3JsZDEyMzQ1Ng==" \
    "https://${ARGO_DOMAIN}:${SERVER_PORT}/sba-vl" || true)"
  public_code="$(awk '/^HTTP/{code=$2} END{print code}' <<<"$public_headers")"
  if grep -qi '^cf-mitigated: *challenge' <<<"$public_headers"; then
    red "Cloudflare 正在返回人机挑战（HTTP ${public_code:-403}），代理客户端无法连接。"
    yellow "请为 ${ARGO_DOMAIN} 的 /sba-vl、/sba-vl2、/sba-vm、/sba-tr 路径关闭或跳过 Challenge/WAF/Bot 防护。"
    failed=1
  elif [[ "$public_code" == "101" ]]; then
    green "公网 WebSocket 链路：握手正常"
  else
    yellow "公网 WebSocket 握手未通过（HTTP ${public_code:-000}）。"
    yellow "请确认 Public Hostname 为 ${ARGO_DOMAIN} → http://localhost:${ORIGIN_PORT}，优选入口 ${SERVER}:${SERVER_PORT} 可用。"
    failed=1
  fi

  return "$failed"
}

prompt_install_values() {
  local value
  read -rp "请输入 Argo Token（必填）: " value
  [[ -n "$value" ]] || die "Argo Token 不能为空。"
  ARGO_TOKEN="$value"
  read -rp "请输入 Argo 域名 [${ARGO_DOMAIN}]: " value
  ARGO_DOMAIN="${value:-$ARGO_DOMAIN}"
  read -rp "请输入 UUID [${UUID}]: " value
  UUID="${value:-$UUID}"
  [[ "${UUID,,}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]] ||
    die "UUID 格式不正确。"
  read -rp "请输入 Cloudflare 优选域名或 IP [${SERVER}]: " value
  SERVER="${value:-$SERVER}"
  read -rp "请输入 Cloudflare 优选端口 [${SERVER_PORT}]: " value
  SERVER_PORT="${value:-$SERVER_PORT}"
  [[ "$ARGO_DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]] || die "Argo 域名格式不正确。"
  [[ "$SERVER" =~ ^[A-Za-z0-9.-]+$ ]] || die "Cloudflare 优选域名或 IPv4 格式不正确。"
  [[ "$SERVER_PORT" =~ ^[0-9]+$ ]] && ((SERVER_PORT >= 1 && SERVER_PORT <= 65535)) ||
    die "Cloudflare 优选端口必须是 1 到 65535。"
}

install_sba() {
  local installer_source
  require_root
  load_env
  prompt_install_values
  installer_source="$(mktemp)"
  install -m 755 "$0" "$installer_source"
  detect_arch
  install_dependencies
  install_sing_box
  install_cloudflared
  # 清理旧版工作目录，避免遗留文件继续生效。
  rm -rf "$WORK_DIR"
  save_env
  write_sing_box_config
  write_nginx_config
  write_services
  create_local_command "$installer_source"
  rm -f "$installer_source"
  systemctl daemon-reload
  systemctl enable nginx sing-box cloudflared
  systemctl restart nginx sing-box cloudflared
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
  systemctl restart cloudflared
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
  local value port
  require_root
  load_env
  [[ -f "$ENV_FILE" ]] || die "SBA 尚未安装。"
  read -rp "请输入新的 Cloudflare 优选域名或 IP [${SERVER}]: " value
  read -rp "请输入新的 Cloudflare 优选端口 [${SERVER_PORT}]: " port
  [[ -z "$value" && -z "$port" ]] && return 0
  value="${value:-$SERVER}"
  port="${port:-$SERVER_PORT}"
  [[ "$value" =~ ^[A-Za-z0-9.-]+$ ]] || die "Cloudflare 优选域名或 IPv4 格式不正确。"
  [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)) ||
    die "Cloudflare 优选端口必须是 1 到 65535。"
  SERVER="$value"
  SERVER_PORT="$port"
  save_env
  generate_nodes
  if health_check; then
    green "Cloudflare 优选入口已更新，节点与运行状态已同步。"
  else
    yellow "Cloudflare 优选入口已更新，但链路检查未全部通过。"
  fi
}

show_nodes() {
  [[ -f "$NODES_FILE" ]] && cat "$NODES_FILE" || die "节点文件不存在，请先安装。"
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
  local old_argo old_sing new_argo new_sing
  require_root
  [[ -f "$ENV_FILE" ]] || die "${PROJECT_NAME} 尚未安装。"
  [[ -f /etc/systemd/system/cloudflared.service && -f /etc/systemd/system/sing-box.service ]] ||
    die "Argo 或 Sing-box 服务文件不存在，请先执行安装。"
  detect_arch
  old_argo="$(local_cloudflared_version || true)"
  old_sing="$(local_sing_box_version || true)"
  install_cloudflared
  install_sing_box
  new_argo="$(local_cloudflared_version || true)"
  new_sing="$(local_sing_box_version || true)"
  systemctl restart cloudflared sing-box
  green "Argo：${old_argo:-未安装} → ${new_argo:-未知}"
  green "Sing-box：${old_sing:-未安装} → ${new_sing:-未知}"
}

manage_bbr() {
  require_root
  command -v curl >/dev/null 2>&1 || die "缺少 curl，无法启动 BBR/内核管理脚本。"
  bash <(curl -fsSL --retry 3 --connect-timeout 10 \
    https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh)
}

show_status() {
  systemctl --no-pager --full status sing-box cloudflared nginx || true
  ss -tulnp
}

restart_services() {
  require_root
  systemctl restart nginx sing-box cloudflared
  green "服务已重启。"
}

uninstall_sba() {
  require_root
  systemctl disable --now sing-box cloudflared 2>/dev/null || true
  rm -f /etc/systemd/system/sing-box.service /etc/systemd/system/cloudflared.service
  rm -f "$NGINX_CONFIG" /usr/local/bin/sb /usr/local/bin/argo-singbox "/usr/local/bin/${COMMAND_NAME}" /usr/local/bin/sing-box /usr/local/bin/cloudflared "$NODES_FILE"
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
7. 升级内核、安装 BBR 等 (${COMMAND_NAME} -b)
8. 卸载 (${COMMAND_NAME} -u)
9. 安装 / 更新 ${PROJECT_NAME}
10. 查看运行状态
11. 重启服务
0. 退出
EOF
    read -rp "请选择: " choice
    case "$choice" in
      1) show_nodes ;;
      2) toggle_service cloudflared Argo ;;
      3) toggle_service sing-box Sing-box ;;
      4) change_token ;;
      5) change_server ;;
      6) sync_versions ;;
      7) manage_bbr ;;
      8) uninstall_sba ;;
      9) install_sba ;;
      10) show_status ;;
      11) restart_services ;;
      0) exit 0 ;;
      *) yellow "请输入 0 到 11。" ;;
    esac
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    -n) show_nodes ;;
    -a) toggle_service cloudflared Argo ;;
    -s) toggle_service sing-box Sing-box ;;
    -t) change_token ;;
    -d) change_server ;;
    -v) sync_versions ;;
    -b) manage_bbr ;;
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
