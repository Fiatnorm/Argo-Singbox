#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="2.0.0"
WORK_DIR="/etc/sba"
ENV_FILE="${WORK_DIR}/sba.env"
SING_BOX_CONFIG="${WORK_DIR}/sing-box.json"
NGINX_CONFIG="/etc/nginx/conf.d/sba.conf"
NODES_FILE="/root/sba_nodes.txt"
LOCAL_SCRIPT="${WORK_DIR}/sb.sh"

DEFAULT_UUID="102a8c7b-8360-44ed-85c8-b1da1aecd363"
DEFAULT_DOMAIN="sb.fiatnorm.us.kg"
DEFAULT_EDGE_HOST=""
DEFAULT_EDGE_PORT="443"

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
  EDGE_HOST="${EDGE_HOST:-${DEFAULT_EDGE_HOST:-$ARGO_DOMAIN}}"
  EDGE_PORT="${EDGE_PORT:-$DEFAULT_EDGE_PORT}"
  ARGO_TOKEN="${ARGO_TOKEN:-}"
}

save_env() {
  install -d -m 700 "$WORK_DIR"
  umask 077
  cat >"$ENV_FILE" <<EOF
UUID='${UUID}'
ARGO_DOMAIN='${ARGO_DOMAIN}'
EDGE_HOST='${EDGE_HOST}'
EDGE_PORT='${EDGE_PORT}'
ARGO_TOKEN='${ARGO_TOKEN}'
EOF
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

install_sing_box() {
  local version archive
  version="$(curl -fsSL https://api.github.com/repos/SagerNet/sing-box/releases/latest |
    sed -n 's/.*"tag_name": *"v\([^"]*\)".*/\1/p' | head -n1)"
  [[ -n "$version" ]] || die "无法获取 sing-box 最新版本。"
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
      }
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
      }
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
      }
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
      }
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
ExecStart=/usr/local/bin/sing-box run -c ${SING_BOX_CONFIG}
Restart=on-failure
RestartSec=3
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
Restart=always
RestartSec=5
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
EOF
}

generate_nodes() {
  local vmess_json vmess_link
  printf -v vmess_json '{\r\n  "v": "2",\r\n  "ps": "GreenCloud-Vm",\r\n  "add": "%s",\r\n  "port": "%s",\r\n  "id": "%s",\r\n  "aid": "0",\r\n  "scy": "auto",\r\n  "net": "ws",\r\n  "type": "none",\r\n  "host": "%s",\r\n  "path": "/sba-vm?ed=2560",\r\n  "tls": "tls",\r\n  "sni": "%s",\r\n  "alpn": "",\r\n  "fp": "",\r\n  "insecure": "0",\r\n  "vcn": "",\r\n  "pcs": ""\r\n}' \
    "$EDGE_HOST" "$EDGE_PORT" "$UUID" "$ARGO_DOMAIN" "$ARGO_DOMAIN"
  vmess_link="$(printf '%s' "$vmess_json" | base64 -w 0)"

  umask 077
  cat >"$NODES_FILE" <<EOF
vless://${UUID}@${EDGE_HOST}:${EDGE_PORT}?encryption=none&security=tls&sni=${ARGO_DOMAIN}&insecure=0&allowInsecure=0&type=ws&host=${ARGO_DOMAIN}&path=%2Fsba-vl2%3Fed%3D2560#GreenCloud-Vl-Path2
vmess://${vmess_link}
trojan://${UUID}@${EDGE_HOST}:${EDGE_PORT}?security=tls&sni=${ARGO_DOMAIN}&insecure=0&allowInsecure=0&type=ws&host=${ARGO_DOMAIN}&path=%2Fsba-tr%3Fed%3D2560#GreenCloud-Tr
vless://${UUID}@${EDGE_HOST}:${EDGE_PORT}?encryption=none&security=tls&sni=${ARGO_DOMAIN}&insecure=0&allowInsecure=0&type=ws&host=${ARGO_DOMAIN}&path=%2Fsba-vl%3Fed%3D2560#GreenCloud-Vl-Path1
EOF
  chmod 600 "$NODES_FILE"
}

create_local_command() {
  install -m 755 "$0" "${LOCAL_SCRIPT}.new"
  mv -f "${LOCAL_SCRIPT}.new" "$LOCAL_SCRIPT"
  ln -sfn "$LOCAL_SCRIPT" /usr/local/bin/sb
}

health_check() {
  local failed=0 public_code port
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

  public_code="$(curl -ksS --http1.1 --max-time 8 -o /dev/null -w '%{http_code}' \
    --connect-to "${ARGO_DOMAIN}:${EDGE_PORT}:${EDGE_HOST}:${EDGE_PORT}" \
    -H "Host: ${ARGO_DOMAIN}" \
    -H "Connection: Upgrade" \
    -H "Upgrade: websocket" \
    -H "Sec-WebSocket-Version: 13" \
    -H "Sec-WebSocket-Key: SGVsbG9Xb3JsZDEyMzQ1Ng==" \
    "https://${ARGO_DOMAIN}:${EDGE_PORT}/sba-vl?ed=2560" || true)"
  if [[ "$public_code" == "101" ]]; then
    green "公网 WSS 链路：握手正常"
  else
    yellow "公网 WSS 链路未通过（HTTP ${public_code:-000}）。"
    yellow "请确认 Cloudflare Public Hostname 为 ${ARGO_DOMAIN} → http://localhost:${ORIGIN_PORT}，DNS 已代理且入口 ${EDGE_HOST}:${EDGE_PORT} 可用。"
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
  [[ "$UUID" =~ ^[0-9a-fA-F-]{36}$ ]] || die "UUID 格式不正确。"
  read -rp "请输入 Cloudflare 优选域名或 IP [${EDGE_HOST}]: " value
  EDGE_HOST="${value:-$EDGE_HOST}"
  read -rp "请输入 Cloudflare TLS 端口 [${EDGE_PORT}]: " value
  EDGE_PORT="${value:-$EDGE_PORT}"
  [[ "$EDGE_PORT" =~ ^(443|2053|2083|2087|2096|8443)$ ]] ||
    die "端口必须是 Cloudflare 支持的 HTTPS 端口：443、2053、2083、2087、2096 或 8443。"
}

install_sba() {
  require_root
  load_env
  prompt_install_values
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
  generate_nodes
  create_local_command
  systemctl daemon-reload
  systemctl enable --now nginx sing-box cloudflared
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
  green "Argo Token 已更新。"
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
  rm -f "$NGINX_CONFIG" /usr/local/bin/sb /usr/local/bin/sing-box /usr/local/bin/cloudflared "$NODES_FILE"
  rm -rf "$WORK_DIR"
  systemctl daemon-reload
  systemctl restart nginx 2>/dev/null || true
  green "SBA 已卸载。"
}

menu() {
  while true; do
    cat <<EOF

SBA 轻量版 v${VERSION}
1. 安装 / 更新 SBA
2. 修改 Argo Token
3. 查看运行状态
4. 查看节点文件
5. 重启服务
6. 卸载 SBA
0. 退出
EOF
    read -rp "请选择: " choice
    case "$choice" in
      1) install_sba ;;
      2) change_token ;;
      3) show_status ;;
      4) [[ -f "$NODES_FILE" ]] && cat "$NODES_FILE" || yellow "节点文件不存在，请先安装。" ;;
      5) restart_services ;;
      6) uninstall_sba ;;
      0) exit 0 ;;
      *) yellow "请输入 0 到 6。" ;;
    esac
  done
}

case "${1:-}" in
  install) install_sba ;;
  token) change_token ;;
  status) show_status ;;
  nodes) [[ -f "$NODES_FILE" ]] && cat "$NODES_FILE" || die "节点文件不存在。" ;;
  restart) restart_services ;;
  uninstall) uninstall_sba ;;
  "") menu ;;
  *) die "未知参数。可用参数：install、token、status、nodes、restart、uninstall。" ;;
esac
