#!/usr/bin/env bash
set -Eeuo pipefail
export UI_LANGUAGE=zh
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NO_COLOR=1 TERM=dumb
source "$ROOT_DIR/argo-singbox.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
ENV_FILE="$TEST_DIR/env"; NODES_CONFIG="$TEST_DIR/nodes.conf"
: >"$ENV_FILE"
printf 'Test|vless|/test|3011|\n' >"$NODES_CONFIG"
require_root() { :; }; load_env() { :; }; ensure_nodes_config() { :; }
service_status() { printf '已启用 · 运行中'; }
traffic_timer_status() { printf '已启用 · 每分钟'; }
warp_status() { printf '未启用 · 可选功能'; }
detect_tcp_brutal() { IS_BRUTAL=true; }
BRUTAL_UP_MBPS=1000 BRUTAL_DOWN_MBPS=1000 WARP_ENABLED=0 WARP_PROXY_PORT=40000 WARP_DOMAINS="" WARP_GEOSITES=""
control_panel() { :; }; runtime_overview() { :; }
for function in menu manage_config manage_services configure_warp configure_warp_domains configure_warp_geosites configure_transport_optimization backup_restore_menu install_menu; do
  for input in '' 0; do
    output="$("$function" <<<"$input"; printf 'SHOULD_NOT_CONTINUE')"
    [[ "$output" != *SHOULD_NOT_CONTINUE* ]]
    [[ "$output" == *'Enter · 默认 | 0 · 退出'* ]]
  done
done
for input in '' n N 0; do ! is_confirmed "$input"; done
is_confirmed y; is_confirmed Y
output="$(read_input '参数 [当前值]：' value <<<0; printf SHOULD_NOT_CONTINUE)"
[[ "$output" != *SHOULD_NOT_CONTINUE* ]]
read_input '参数 [当前值]：' value <<<'' >/dev/null
[[ -z "$value" ]]
output="$(read_input '参数 [必填]：' value <<<''; printf SHOULD_NOT_CONTINUE)"
[[ "$output" == *SHOULD_NOT_CONTINUE* ]]
# Validate the displayed root mapping by executing every selection with stubs.
show_nodes() { printf ACTION_nodes; }; manage_config() { printf ACTION_config; }
manage_services() { printf ACTION_services; }; traffic_statistics_menu() { printf ACTION_traffic; }
doctor() { printf ACTION_diagnostic; }; sync_versions() { printf ACTION_update; }
backup_restore_menu() { printf ACTION_backup; }; manage_bbr() { printf ACTION_tools; }
install_menu() { printf ACTION_install; }; uninstall_project() { printf ACTION_uninstall; }
expected=(nodes config services traffic diagnostic update backup tools install uninstall)
for index in {1..10}; do
  output="$(menu <<<"$index")"
  [[ "$output" == *"ACTION_${expected[index-1]}" ]]
done
# Transport actions: 4 bandwidth, 5 h2mux enable, 6 h2mux disable.
begin_config_change() { :; }
apply_runtime_config() { printf 'ACTION_TRANSPORT:%s:%s:%s:%s' "$MULTIPLEX_ENABLED" "$TCP_BRUTAL_ENABLED" "$BRUTAL_UP_MBPS" "$BRUTAL_DOWN_MBPS"; }
output="$(configure_transport_optimization <<<'4
800
1200')"
[[ "$output" == *ACTION_TRANSPORT:1:1:800:1200* ]]
MULTIPLEX_ENABLED=0 TCP_BRUTAL_ENABLED=0
output="$(configure_transport_optimization <<<5)"
[[ "$output" == *ACTION_TRANSPORT:1:0:1000:1000* ]]
MULTIPLEX_ENABLED=1 TCP_BRUTAL_ENABLED=1
output="$(configure_transport_optimization <<<'6
y')"
[[ "$output" == *ACTION_TRANSPORT:0:0:1000:1000* ]]
output="$(configure_transport_optimization <<<'6
')"
[[ "$output" != *ACTION_TRANSPORT* ]]
configure_warp_domains() { printf ACTION_domains; }; configure_warp_geosites() { printf ACTION_geosites; }
output="$(configure_warp <<<3)"; [[ "$output" == *ACTION_domains* ]]
output="$(configure_warp <<<4)"; [[ "$output" == *ACTION_geosites* ]]
output="$(configure_warp <<<'2
')"; [[ "$output" != *ACTION_TRANSPORT* ]]
printf '%s\n' UI_INTERACTION_SMOKE_OK
