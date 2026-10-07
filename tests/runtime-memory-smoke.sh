#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/argo-singbox.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
PROC_ROOT="$TEST_DIR/proc"
CGROUP_ROOT="$TEST_DIR/cgroup"
WARP_ENABLED=0
systemctl() {
  local pid group
  case "$2" in
    nginx) pid=101; group=nginx ;;
    "$CORE_SERVICE") pid=201; group=core ;;
    "$ARGO_SERVICE") pid=301; group=tunnel ;;
    "$TRAFFIC_SERVICE") pid=401; group=traffic ;;
    warp-svc) pid=501; group=warp ;;
    *) return 1 ;;
  esac
  case "$4" in MainPID) printf '%s\n' "$pid" ;; ControlGroup) printf '/%s\n' "$group" ;; esac
}
ps() { printf '%s\n' "$$ 1" '101 1' '102 101' '201 1' '301 1' '401 1' '501 1' '999 1'; }
for item in "$$:1024" 101:2048 102:4096 201:8192 301:4096 401:512 501:16384 999:1048576; do
  pid="${item%:*}"; rss="${item#*:}"
  mkdir -p "$PROC_ROOT/$pid"
  printf 'VmRSS:\t%s kB\n' "$rss" >"$PROC_ROOT/$pid/status"
done
for group in nginx nginx/worker core tunnel traffic warp; do mkdir -p "$CGROUP_ROOT/$group"; done
printf '101\n102\n' >"$CGROUP_ROOT/nginx/cgroup.procs"
printf '102\n' >"$CGROUP_ROOT/nginx/worker/cgroup.procs"
printf '201\n' >"$CGROUP_ROOT/core/cgroup.procs"
printf '301\n301\n' >"$CGROUP_ROOT/tunnel/cgroup.procs"
printf '401\n' >"$CGROUP_ROOT/traffic/cgroup.procs"
printf '501\n' >"$CGROUP_ROOT/warp/cgroup.procs"
[[ "$(runtime_memory_usage)" == '19.5 MiB' ]]
WARP_ENABLED=1
[[ "$(runtime_memory_usage)" == '35.5 MiB' ]]
# Without cgroups, Nginx workers are still counted through MainPID ancestry.
CGROUP_ROOT="$TEST_DIR/missing"
[[ "$(runtime_memory_usage)" == '35.5 MiB' ]]
printf 'Name: inaccessible\n' >"$PROC_ROOT/201/status"
[[ "$(runtime_memory_usage)" == '27.5 MiB · 部分进程不可读' ]]
PROC_ROOT="$TEST_DIR/missing-proc"
[[ "$(runtime_memory_usage)" == '未知 · 进程内存不可读' ]]
printf '%s\n' RUNTIME_MEMORY_SMOKE_OK
