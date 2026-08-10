#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../ags.sh
source "${ROOT_DIR}/ags.sh"

[[ "$PROJECT_NAME" == "AGS" ]]
[[ "$PROJECT_CODE" == "AGS" ]]
[[ "$COMMAND_NAME" == "ags" && "$COMMAND_NAME_UPPER" == "AGS" ]]
[[ "$WORK_DIR" == "/etc/ags" && "$LOCAL_SCRIPT" == "/etc/ags/ags.sh" ]]
[[ "$CORE_SERVICE" == "ags-core" && "$ARGO_SERVICE" == "ags-tunnel" ]]
[[ "$TRAFFIC_SERVICE" == "ags-traffic" && "$TRAFFIC_TIMER" == "ags-traffic" ]]

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf -- "$TEST_ROOT"' EXIT

# Windows Git Bash cannot always apply POSIX modes in its temporary directory.
# The migration under test only needs install(1)'s directory-creation form.
install() {
  if [[ "${1:-}" == "-d" ]]; then
    shift
    if [[ "${1:-}" == "-m" ]]; then
      shift 2
    fi
    mkdir -p -- "$@"
    return
  fi
  command install "$@"
}

set_test_paths() {
  WORK_DIR="$1"
  PREVIOUS_WORK_DIR="$2"
  LEGACY_WORK_DIR="$3"
  CONFIG_DIR="${WORK_DIR}/config"
  DATA_DIR="${WORK_DIR}/data"
  SUBSCRIPTION_DIR="${WORK_DIR}/subscriptions"
  ENV_FILE="${CONFIG_DIR}/ags.env"
  NODES_CONFIG="${CONFIG_DIR}/nodes.conf"
  LOCAL_SCRIPT="${WORK_DIR}/ags.sh"
  BACKUP_DIR="${WORK_DIR}/backup"
  MANAGED_FILE="${WORK_DIR}/managed"
  LEGACY_MIGRATED=0
}

# A normal existing installation is not a legacy migration. In particular, the
# installed script must never be moved onto itself during a repeated install.
set_test_paths \
  "${TEST_ROOT}/current" \
  "${TEST_ROOT}/absent-asb" \
  "${TEST_ROOT}/absent-legacy"
install -d -m 700 "$WORK_DIR"
printf '%s\n' '#!/usr/bin/env bash' >"$LOCAL_SCRIPT"
printf '%s\n' 'project=AGS' >"$MANAGED_FILE"
migrate_legacy_install
[[ -f "$LOCAL_SCRIPT" ]]
[[ ! -e "${BACKUP_DIR}/pre-ags-namespace" ]]

# A real legacy flat environment file is still migrated and backed up, while
# the script already at LOCAL_SCRIPT remains in place.
set_test_paths \
  "${TEST_ROOT}/flat-legacy" \
  "${TEST_ROOT}/absent-asb-2" \
  "${TEST_ROOT}/absent-legacy-2"
install -d -m 700 "$WORK_DIR"
printf '%s\n' '#!/usr/bin/env bash' >"$LOCAL_SCRIPT"
printf '%s\n' 'UUID=test-value' >"${WORK_DIR}/asb.env"
migrate_legacy_install
[[ -f "$LOCAL_SCRIPT" ]]
[[ -f "$ENV_FILE" ]]
[[ ! -e "${WORK_DIR}/asb.env" ]]
[[ -f "${BACKUP_DIR}/pre-ags-namespace/asb.env" ]]

# The immediately previous namespace is migrated to /etc/ags semantics while
# preserving a compatibility symlink until the runtime health check succeeds.
set_test_paths \
  "${TEST_ROOT}/ags-current" \
  "${TEST_ROOT}/argo-singbox-previous" \
  "${TEST_ROOT}/asb-legacy"
install -d -m 700 "${PREVIOUS_WORK_DIR}/config"
printf '%s\n' '#!/usr/bin/env bash' >"${PREVIOUS_WORK_DIR}/argo-singbox.sh"
printf '%s\n' 'project=ASB' >"${PREVIOUS_WORK_DIR}/managed"
printf '%s\n' 'UUID=test-value' >"${PREVIOUS_WORK_DIR}/config/argo-singbox.env"
migrate_legacy_install
[[ -d "$WORK_DIR" ]]
[[ -e "$PREVIOUS_WORK_DIR" || -L "$PREVIOUS_WORK_DIR" ]]
[[ -f "${BACKUP_DIR}/pre-ags-namespace/argo-singbox.sh" ]]
migrate_project_layout
[[ -f "$ENV_FILE" ]]
[[ ! -e "${CONFIG_DIR}/argo-singbox.env" ]]

printf '%s\n' 'INSTALLER_MIGRATION_SMOKE_OK'
