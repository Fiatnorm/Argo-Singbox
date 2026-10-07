#!/usr/bin/env bash
set -Eeuo pipefail
export UI_LANGUAGE=zh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../argo-singbox.sh
source "${ROOT_DIR}/argo-singbox.sh"

[[ "$PROJECT_NAME" == "Argo-Singbox" ]]
[[ "$PROJECT_CODE" == "AGS" ]]
[[ "$COMMAND_NAME" == "ags" && "$COMMAND_NAME_UPPER" == "AGS" ]]
[[ "$WORK_DIR" == "/etc/argo-singbox" && "$LOCAL_SCRIPT" == "/etc/argo-singbox/argo-singbox.sh" ]]
[[ "$PREVIOUS_LOCAL_SCRIPT" == "/etc/argo-singbox/Argo-Singbox.sh" ]]
[[ "$CORE_SERVICE" == "argo-singbox-core" && "$ARGO_SERVICE" == "argo-singbox-tunnel" ]]
[[ "$TRAFFIC_SERVICE" == "argo-singbox-traffic" && "$TRAFFIC_TIMER" == "argo-singbox-traffic" ]]

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
  ENV_FILE="${CONFIG_DIR}/argo-singbox.env"
  NODES_CONFIG="${CONFIG_DIR}/nodes.conf"
  LOCAL_SCRIPT="${WORK_DIR}/argo-singbox.sh"
  PREVIOUS_LOCAL_SCRIPT="${WORK_DIR}/Argo-Singbox.sh"
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
printf '%s\n' 'project=Argo-Singbox' >"$MANAGED_FILE"
migrate_legacy_install
[[ -f "$LOCAL_SCRIPT" ]]
[[ ! -e "${BACKUP_DIR}/pre-argo-singbox-namespace" ]]

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
[[ -f "${BACKUP_DIR}/pre-argo-singbox-namespace/asb.env" ]]

# The immediately previous /etc/ags namespace is migrated to Argo-Singbox while
# preserving a compatibility symlink until the runtime health check succeeds.
set_test_paths \
  "${TEST_ROOT}/argo-singbox-current" \
  "${TEST_ROOT}/ags-previous" \
  "${TEST_ROOT}/asb-legacy"
install -d -m 700 "${PREVIOUS_WORK_DIR}/config"
printf '%s\n' '#!/usr/bin/env bash' >"${PREVIOUS_WORK_DIR}/ags.sh"
printf '%s\n' 'project=AGS' >"${PREVIOUS_WORK_DIR}/managed"
printf '%s\n' 'UUID=test-value' >"${PREVIOUS_WORK_DIR}/config/ags.env"
migrate_legacy_install
[[ -d "$WORK_DIR" ]]
[[ -e "$PREVIOUS_WORK_DIR" || -L "$PREVIOUS_WORK_DIR" ]]
[[ -f "${BACKUP_DIR}/pre-argo-singbox-namespace/ags.sh" ]]
migrate_project_layout
[[ -f "$ENV_FILE" ]]
[[ ! -e "${CONFIG_DIR}/ags.env" ]]

printf '%s\n' 'INSTALLER_MIGRATION_SMOKE_OK'
