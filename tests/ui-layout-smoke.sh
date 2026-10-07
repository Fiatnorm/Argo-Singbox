#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
printf 'NAME="Debian GNU/Linux"\nVERSION_ID=13\nPRETTY_NAME="Debian GNU/Linux 13 (trixie)"\n' >"$TEST_DIR/os-release"
for language in zh en; do
  for locale in C C.UTF-8; do
    UI_LANGUAGE="$language" LC_ALL="$locale" NO_COLOR=1 TERM=dumb bash -c '
      source "$1"
      uname() { case "$1" in -r) printf 6.12.101+deb13-amd64 ;; -m) printf x86_64 ;; esac; }
      summary_definition="$(declare -f system_summary)"
      summary_definition="${summary_definition//\/etc\/os-release/$2}"
      eval "$summary_definition"
      [[ "$(system_summary)" == "Debian GNU/Linux 13 · amd64 · Kernel 6.12.101" ]]
      [[ "$(display_width "Traffic collector")" == 17 ]]
      [[ "$(display_width "系统环境")" == 8 ]]
      local_core_version() { printf 1.13.18; }
      local_cloudflared_version() { printf 2026.7.3; }
      read_traffic_totals() { printf "1024|2048"; }
      service_status() { printf "已启用 · 运行中"; }
      traffic_timer_status() { printf "已启用 · 每分钟"; }
      warp_status() { printf "未启用 · 可选功能"; }
      tcp_brutal_status() { printf "已启用 · 1000/1000 Mbps"; }
      node_overview() { printf "VLESS 1 · VMess 2 · Trojan 1"; }
      public_ipv4_details() { printf "107.173.211.29|US|AS36352|HostPapa"; }
      public_ipv6_details() { return 1; }
      runtime_memory_usage() { printf "347.2 MiB"; }
      ARGO_DOMAIN=example.com SERVER=polestar.com SERVER_PORT=443 ORIGIN_PORT=3010
      SCRIPT_RUNS_REQUESTED=1 SCRIPT_RUNS_TOTAL=22 SCRIPT_RUNS_SHOWN=0
      control_panel
      runtime_overview
      brand "Argo-Singbox · 控制中心" main
      brand "Argo-Singbox · 一个用于检查提示换行的很长的页面名称" default
    ' _ "$ROOT_DIR/argo-singbox.sh" "$TEST_DIR/os-release" >"$TEST_DIR/$language-$locale"
  done
done
python - "$TEST_DIR" <<'PY'
import pathlib, sys, unicodedata
root = pathlib.Path(sys.argv[1])
def width(s):
    return sum(0 if unicodedata.combining(c) else 2 if unicodedata.east_asian_width(c) in ('W','F') else 1 for c in s)
for language in ['zh', 'en']:
    assert (root / (language+'-C')).read_bytes() == (root / (language+'-C.UTF-8')).read_bytes()
    lines = (root / (language+'-C')).read_text(encoding='utf-8').splitlines()
    assert lines[0] == '' and lines[1].startswith('    ___'), 'exactly one leading blank line'
    expected = {
        'zh': [('功能特性','WS/TLS'), ('系统环境','Debian'), ('脚本统计','Executed 22 times'), ('Argo Tunnel','已启用'), ('Sing-box Core','已启用'), ('流量采集','已启用'), ('全局流量','↑'), ('运行内存','347.2 MiB'), ('组件版本','Sing-box 1.13.18')],
        'en': [('Features','WS/TLS'), ('System','Debian'), ('Script runs','Executed 22 times'), ('Argo Tunnel','Enabled'), ('Sing-box Core','Enabled'), ('Traffic collector','Enabled'), ('Traffic total','↑'), ('Memory','347.2 MiB'), ('Components','Sing-box 1.13.18')]
    }[language]
    for label, value in expected:
        row = next(x for x in lines if x.startswith(label+' '))
        expected_width = 14 if label in ('功能特性','系统环境','脚本统计','Features','System','Script runs') else 20
        assert width(row[:row.index(value)]) == expected_width, (label, row)
    header = next(x for x in lines if x.startswith('Argo-Singbox  v'))
    assert header == 'Argo-Singbox  v2026.10.07 · Argo Tunnel · Sing-box Core'
    assert width(header[:header.index('v2026')]) == 14
    system = next(x for x in lines if x.startswith(('系统环境 ', 'System ')))
    assert system.endswith('Kernel 6.12.101')
    assert all(not x.startswith(('节点落地 IP ', 'Egress IP ', 'AGS ')) for x in lines)
    for row in lines:
        if 'Enter ·' in row:
            assert width(row) <= 64, row
    version = next(x for x in lines if x.startswith(('组件版本 ', 'Components ')))
    assert version.endswith('Sing-box 1.13.18 · cloudflared 2026.7.3') and 'AGS' not in version
PY
# Only the two component versions receive yellow; names and separators remain white.
UI_LANGUAGE=zh bash -c '
  source "$1"
  C_BRIGHT_WHITE=W C_BRIGHT_YELLOW=Y C_BRIGHT_CYAN=C C_RESET=R
  local_core_version() { printf 1.13.18; }; local_cloudflared_version() { printf 2026.7.3; }
  row="$(component_version_value)"
  [[ "$row" == *"WSing-box Y1.13.18W · cloudflared Y2026.7.3R" ]]
' _ "$ROOT_DIR/argo-singbox.sh"
printf 'UI_LAYOUT_SMOKE_OK\n'
