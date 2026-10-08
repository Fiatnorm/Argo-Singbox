#!/usr/bin/env bash
set -Eeuo pipefail

VERSION="2026.10.08"
PROJECT_NAME="Argo-Singbox"
PROJECT_CODE="AGS"
SCRIPT_NAME="argo-singbox.sh"
CHECKSUM_NAME="argo-singbox.sh.sha256"
COMMAND_NAME="ags"
COMMAND_NAME_UPPER="AGS"
PROJECT_REPO="Fiatnorm/Argo-Singbox"
PROJECT_BRANCH="main"
SING_BOX_REPO="SagerNet/sing-box"
TCP_BRUTAL_REPO="apernet/tcp-brutal"
TCP_BRUTAL_INSTALLER_REV="f11e52d88c7ad2285896de018c2d96d4687f0ab6"
TCP_BRUTAL_INSTALLER_SHA256="cd7615dd64836d8b239124cad776ac9e5a330830147e1a6892cb69e1ae6c9de6"
TCP_BRUTAL_VERSION="1.0.3"
TCP_BRUTAL_DKMS_SHA256="38526721f2e8a8c1907eb289d80526fc2bee9ca09b1f89d91362cea8ef1aad04"
WORK_DIR="/etc/argo-singbox"
WORK_DIR_NAME="${WORK_DIR##*/}"
PREVIOUS_WORK_DIR="/etc/ags"
LEGACY_WORK_DIR="/etc/asb"
CONFIG_DIR="${WORK_DIR}/config"
DATA_DIR="${WORK_DIR}/data"
SUBSCRIPTION_DIR="${WORK_DIR}/subscriptions"
ENV_FILE="${CONFIG_DIR}/argo-singbox.env"
SING_BOX_CONFIG="${CONFIG_DIR}/sing-box.json"
NGINX_CONFIG="/etc/nginx/conf.d/argo-singbox.conf"
LEGACY_NGINX_CONFIG="/etc/nginx/conf.d/ags.conf"
OLDER_NGINX_CONFIG="/etc/nginx/conf.d/argofusion.conf"
NODES_FILE="${DATA_DIR}/nodes.txt"
LEGACY_NODES_FILE="/root/argo-singbox_nodes.txt"
LOCAL_SCRIPT="${WORK_DIR}/argo-singbox.sh"
PREVIOUS_LOCAL_SCRIPT="${WORK_DIR}/Argo-Singbox.sh"
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
RULE_SET_DIR="${DATA_DIR}/rule-set"
CORE_SERVICE="argo-singbox-core"
ARGO_SERVICE="argo-singbox-tunnel"
TRAFFIC_SERVICE="argo-singbox-traffic"
TRAFFIC_TIMER="argo-singbox-traffic"
PREVIOUS_CORE_SERVICE="ags-core"
PREVIOUS_ARGO_SERVICE="ags-tunnel"
PREVIOUS_TRAFFIC_SERVICE="ags-traffic"
PREVIOUS_TRAFFIC_TIMER="ags-traffic"
LEGACY_CORE_SERVICE="asb-core"
LEGACY_ARGO_SERVICE="asb-tunnel"
LEGACY_MIGRATED=0

DEFAULT_SERVER="polestar.com"
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
MULTIPLEX_ENABLED=1
TCP_BRUTAL_ENABLED=1
WARP_GEOSITES=""
OUTBOUND_IP_FAMILY="auto"

UI_LANGUAGE="${UI_LANGUAGE:-zh}"
SCRIPT_STATS_URL="https://abacus.jasoncameron.dev"
SCRIPT_STATS_NAMESPACE="ags"
SCRIPT_STATS_KEY="fiatnorm"
SCRIPT_RUNS_TOTAL=""
SCRIPT_RUNS_REQUESTED=0
SCRIPT_RUNS_SHOWN=0
UI_WIDTH=64
UI_LABEL_WIDTH=18
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
if [[ -t 2 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != "dumb" ]]; then
  C_ERR_RESET=$'\033[0m'
  C_ERR_RED=$'\033[91m'
else
  C_ERR_RESET=""
  C_ERR_RED=""
fi
# Embedded UI translations: no translation service is used at runtime.
declare -A UI_EN=(
  ['上传']=Upload
  ['上传带宽']='Upload bandwidth'
  ['上传带宽无效。']='Invalid upload bandwidth.'
  ['上传带宽无效，请输入']='Invalid upload bandwidth, please enter'
  ['下载']=Download
  ['下载失败（已尝试直连和']='Download failed (tried direct and '
  ['下载带宽']='Download bandwidth'
  ['下载带宽无效。']='Invalid download bandwidth.'
  ['下载带宽无效，请输入']='Invalid download bandwidth, please enter'
  ['不可用']=Unavailable
  ['不可用 · 缺少 brutal 内核模块']='Unavailable · Missing brutal kernel module'
  ['不可达']='Not reachable'
  ['不存在']='does not exist'
  ['不支持的节点协议：']='Unsupported node protocols:'
  ['不能使用其他版本头文件替代。']='Other version header files cannot be used instead.'
  ['不能删除最后一个']='Cannot delete the last one'
  ['与']=with
  ['与域名']='with domain name'
  ['与旧目录']='with old directory'
  ['与根分区空间充足。']='There is plenty of space with the root partition.'
  ['且不属于本项目。为避免服务冲突，安装已停止。']='and does not belong to this project. To avoid service conflicts, the installation has been stopped.'
  ['两个旧安装目录，请先人工核对。']='Two old installation directories, please check manually first.'
  ['个提醒']=warnings
  ['个未监听']='not monitored'
  ['个错误']=errors
  ['中没有可安装的']='There is nothing to install in'
  ['为']=for
  ['主机']=Host
  ['也会同时停用。']='will also be deactivated at the same time.'
  ['人机挑战（']='Human-machine challenge ('
  ['仅打开节点备份与恢复菜单，不接受文件路径参数。']='Only opens the node backup and recovery menu and does not accept file path parameters.'
  ['仅支持']='Only supports'
  ['仅支持通过']='Only supports passing'
  ['仅检测到']='Only detected'
  ['代理']=agent
  ['代理端口不能与']='The proxy port cannot be used with'
  ['代理端口不能与流量统计']='Proxy port cannot be used with traffic statistics'
  ['代理端口不能与节点监听端口相同：']='The proxy port cannot be the same as the node listening port:'
  ['代理端口不能占用']='The proxy port cannot be occupied'
  ['代理端口不能占用流量统计']='The proxy port cannot occupy traffic statistics'
  ['代理端口不能占用节点监听端口']='The proxy port cannot occupy the node listening port'
  ['代理端口冲突：']='Proxy port conflict:'
  ['代理端口无效。']='The proxy port is invalid.'
  ['以']=to
  ['优选入口']='Preferred entry'
  ['优选入口无效']='The preferred entrance is invalid'
  ['优选入口格式不正确。']='The preferred entry format is incorrect.'
  ['优选入口端口无效']='The preferred entry port is invalid'
  ['优选入口端口无效。']='The preferred ingress port is invalid.'
  ['传输优化']=Transport
  ['传输优化选项无效']='Transport optimization option is invalid'
  ['传输检查']='transmission check'
  ['传输路径']='Transport path'
  ['传输路径格式错误：']='The transmission path format is incorrect:'
  ['但缺少项目所有权标记，拒绝自动迁移。']='But the project ownership tag is missing, rejecting automatic migration.'
  ['低于']='lower than'
  ['低于官方最低要求']='Below official minimum requirements'
  ['使用']=Use
  ['使用最新备份：']='Use the latest backup:'
  ['保持当前；']='remain current;'
  ['保留非本项目旧服务：']='Retain old services other than this project:'
  ['修改节点']='Edit node'
  ['修改配置']='Modify configuration'
  ['停用']=Disable
  ['全局']='overall situation'
  ['全局流量']='Traffic total'
  ['全局流量统计已通过。']='Global traffic statistics passed.'
  ['全局流量统计无效。']='Global traffic statistics are invalid.'
  ['全局统计']='Total traffic'
  ['全部服务']='All services'
  ['公网']='Public network'
  ['公网传输探测失败（']='Public network transmission detection failed ('
  ['公网传输探测超时，未视为安装失败；请用客户端实测。']='The public network transmission detection timeout is not considered an installation failure; please use the client to test.'
  ['公网出口']='Public egress'
  ['公网出口检测']='Public egress detection'
  ['公网出口，未生成']='Public network exit, not generated'
  ['共四类订阅']='A total of four types of subscriptions'
  ['内核、网络参数或系统磁盘']='Kernel, network parameters or system disk'
  ['内核低于']='The kernel is lower than'
  ['内核升级引导']='Kernel upgrade boot'
  ['内核头文件']='Kernel header files'
  ['内核安装需要额外磁盘空间，请确保']='Kernel installation requires additional disk space, please make sure'
  ['内核模块']='kernel module'
  ['内核管理脚本。']='Kernel management script.'
  ['内核软件包']='Kernel package'
  ['内核配置']='Kernel configuration'
  ['内核预检']='Kernel preflight'
  ['写入']=write
  ['出口']=export
  ['出口不可用']='Exit not available'
  ['出口只能选择']='Export can only be selected'
  ['出站']=Outbound
  ['出站地址族']='outbound address family'
  ['出站已切换为']='Outbound has been switched to'
  ['出站配置']='Outbound configuration'
  ['分流']=Routing
  ['分流。']=Diversion.
  ['分流已停用']='Diversion is disabled'
  ['分流规则']='Routing rules'
  ['分流？']='Diversion?'
  ['分类。']=classification.
  ['分类不能为空。']='Category cannot be empty.'
  ['分类无效：']='Invalid classification:'
  ['分类：']=Category:
  ['创建备份']='Create backup'
  ['删除分类']='Delete category'
  ['删除域名']='Delete domain name'
  ['删除操作']='Delete operation'
  ['删除节点']='Delete node'
  ['到']=Arrive
  ['刷新后当前内核仍不满足']='The current kernel is still not satisfied after refreshing'
  ['刷新统计']='Refresh traffic'
  ['功能特性']=Features
  ['协议']=Protocol
  ['占用']=occupy
  ['原因']=Reason
  ['原因：定时器已停止']='Reason: The timer has stopped'
  ['原始节点']='Raw nodes'
  ['原始节点订阅']='Raw subscription'
  ['原始订阅']='Raw subscription'
  ['节点链接格式']='Node links'
  ['反代）：']='Anti-generation):'
  ['发布包结构无效。']='The release package structure is invalid.'
  ['发布包缺少']='Release package missing'
  ['发行版代号，不能安全配置']='Release codename, cannot be safely configured'
  ['发行版新内核及其匹配头文件。']='Release the new kernel and its matching header files.'
  ['取消']=Cancel
  ['可取消本次安装。']='This installation can be canceled.'
  ['可安装']=Installable
  ['可用落地']='Available egress'
  ['可用逗号分隔']='Can be separated by commas'
  ['可能修改']='may be modified'
  ['可能被其他网站使用']='May be used by other websites'
  ['可输入域名']='Domain name can be entered'
  ['可选功能']=Optional
  ['合计']=Total
  ['同意安装']='Agree to install'
  ['同时存在，请先人工核对，拒绝自动覆盖。']='If they exist at the same time, please check manually first and refuse automatic overwriting.'
  ['同时抢占节点端口。']='Seize node ports at the same time.'
  ['后重试。']='Try again later.'
  ['启停']='Start and stop'
  ['启停配置无效。']='The start and stop configuration is invalid.'
  ['启动标识']='Startup ID'
  ['启动第三方系统脚本']='Start third-party system scripts'
  ['启用']=Enable
  ['和']=and
  ['和当前业务连接，请先保存其他任务。']='To connect to the current business, please save other tasks first.'
  ['回源']=Origin
  ['回源占用']='Back to source occupation'
  ['回源地址']='Return to source address'
  ['回源已更新：']='The source has been updated:'
  ['回源端口']='Return-to-origin port'
  ['回源端口会占用']='The return-to-origin port will be occupied'
  ['回源端口冲突']='Back-to-origin port conflict'
  ['回源端口冲突：']='Return-to-origin port conflict:'
  ['回源端口无效']='The return-to-origin port is invalid'
  ['回源端口无效。']='The return-to-origin port is invalid.'
  ['回源端口相同。']='The return-to-origin port is the same.'
  ['固定隧道']='fixed tunnel'
  ['在线安装']='Online installation'
  ['在线安装会先校验并替换本地脚本。']='Online installation will first verify and replace local scripts.'
  ['域名']=Domain
  ['域名。']='domain name.'
  ['域名无效']='Invalid domain name'
  ['域名格式不正确。']='The domain name format is incorrect.'
  ['域名规则']='Domain rules'
  ['域名：']='Domain name:'
  ['基础服务']='Basic services'
  ['备份不能直接保存到项目根目录。']='Backups cannot be saved directly to the project root directory.'
  ['备份位置']='Backup location'
  ['备份归档']='Backup archive'
  ['备份归档不包含可恢复的节点配置']='Backup archive does not contain recoverable node configuration'
  ['备份归档为空。']='The backup archive is empty.'
  ['备份归档创建失败。']='Backup archive creation failed.'
  ['备份归档包含符号链接或其他特殊文件，拒绝恢复。']='The backup archive contains symbolic links or other special files, which refuses to be restored.'
  ['备份归档包含越界路径，拒绝恢复。']='The backup archive contains an out-of-bounds path and is refused recovery.'
  ['备份恢复']='Backup / Restore'
  ['备份操作']='Backup operation'
  ['备份文件不存在：']='The backup file does not exist:'
  ['备份文件夹必须使用绝对路径。']='The backup folder must use an absolute path.'
  ['备份文件必须以']='The backup file must end with'
  ['备份来源']='Backup source'
  ['备份目录中没有可恢复的归档：']='There are no recoverable archives in the backup directory:'
  ['备份结构中缺少']='missing from backup structure'
  ['备份节点配置']='Backup node configuration'
  ['备份路径必须使用绝对路径。']='The backup path must use an absolute path.'
  ['备份配置']='Backup configuration'
  ['失败']=Failed
  ['如']='Such as'
  ['字段或节点无效']='Field or node is invalid'
  ['安装']=Install
  ['安装。']=Installation.
  ['安装依赖准备失败。']='Installation dependency preparation failed.'
  ['安装准备']='Installation preparation'
  ['安装后还需按官方说明为公网接口启用']='After installation, you need to enable the public network interface according to the official instructions.'
  ['安装器']=installer
  ['安装器。']=installer.
  ['安装失败；当前发行版可能不受']='Installation failed; current distribution may not be supported'
  ['安装完成，服务检查通过。']='The installation is complete and the service check passed.'
  ['安装已停止，未覆盖现有服务。']='Installation stopped and existing services were not overwritten.'
  ['安装已完成，但服务检查未全部通过；请修复后再使用节点。']='The installation is complete, but all service checks did not pass; please repair before using the node.'
  ['安装方式']='Installation method'
  ['安装条件。']='Installation conditions.'
  ['安装目录迁移为']='The installation directory is moved to'
  ['安装脚本与校验值暂不一致，正在重新获取（']='The installation script and the verification value are temporarily inconsistent and are being obtained again ('
  ['安装说明']='Installation instructions'
  ['安装配置']='Installation configuration'
  ['完整']=complete
  ['完整健康检查通过前，保留旧服务与目录兼容链接以便回退。']='Until the full health check passes, the old service and directory compatibility links are retained for rollback.'
  ['官方']=official
  ['官方依赖。']='Official reliance.'
  ['官方安装器']='Official installer'
  ['官方安装器执行失败。']='The official installer failed to execute.'
  ['官方安装器语法检查失败。']='The official installer syntax check failed.'
  ['官方核心已更新，但全局流量账本未能初始化。']='The official core has been updated, but the global traffic ledger failed to initialize.'
  ['定时器已停止']='The timer has stopped'
  ['定时采集']='Regular collection'
  ['实际域名为']='The actual domain name is'
  ['客户端、注册与软件源？']='Client, registration and software source?'
  ['客户端。']=client.
  ['客户端切换到本地代理模式。']='The client switches to local proxy mode.'
  ['客户端安装完成。']='Client installation is complete.'
  ['客户端注册失败。']='Client registration failed.'
  ['客户端重新注册失败。']='Client re-registration failed.'
  ['客户端？']='Client?'
  ['密码']=Password
  ['将删除']='will be deleted'
  ['将安装']='will install'
  ['将检查更新']='Will check for updates'
  ['将迁移为项目专属服务名。']='Will be migrated to project-specific service name.'
  ['尚未安装。']='Not installed yet.'
  ['尚未采集']='Not collected yet'
  ['工具']=Tools
  ['已保留当前内核运行；请稍后手动重启。']='The current kernel has been left running; please restart manually later.'
  ['已停止']=Stopped
  ['已停止占用节点端口的旧项目服务：']='The old project service occupying the node port has been stopped:'
  ['已停止遗留项目核心进程']='Legacy project core process stopped'
  ['已停用。']=Disabled.
  ['已停用；内核模块仍保留。']='Deprecated; kernel modules remain.'
  ['已先停用新服务再恢复旧服务，避免新旧']='New services have been deactivated first and then old services restored to avoid new and old services.'
  ['已关闭']=Closed
  ['已加载']=Loaded
  ['已卸载']=Uninstalled
  ['已取消']=Canceled
  ['已取消修改']='Changes cancelled'
  ['已取消停用']=Deactivated
  ['已取消内核升级']='Kernel upgrade canceled'
  ['已取消删除']=Undelete
  ['已取消卸载']='Uninstall canceled'
  ['已取消启动']='Startup canceled'
  ['已取消安装']='Installation canceled'
  ['已取消安装，未写入配置。']='The installation has been canceled and the configuration has not been written.'
  ['已取消重置']='Reset canceled'
  ['已同步启用。']='Sync enabled.'
  ['已启动']=Started
  ['已启用']=Enabled
  ['已启用。']=Enabled.
  ['已启用；']='Enabled;'
  ['已安装']=Installed
  ['已安装但']='Installed but'
  ['已安装并加载，服务端与订阅配置已同步。']='Installed and loaded, server and subscription configurations have been synchronized.'
  ['已安装，但找不到']='Installed but not found'
  ['已将']=Already
  ['已将现有配置、节点和订阅文件迁入分类目录。']='Existing configuration, node, and subscription files have been moved into the category directory.'
  ['已恢复修改前配置']='Configuration before modification has been restored'
  ['已恢复到执行恢复操作前的状态。']='Restored to the state before the restore operation was performed.'
  ['已恢复旧服务并保留旧目录兼容链接。']='The old service has been restored and old catalog compatibility links retained.'
  ['已改用']='Already used'
  ['已是目标版本。']='Already the target version.'
  ['已更新：']=Updated:
  ['已替换输入域名']='The input domain name has been replaced'
  ['已被其他节点使用']='Already used by other nodes'
  ['已被占用']='Already occupied'
  ['已读取配置文件：']='Configuration file read:'
  ['已通过']=Passed
  ['已配置']=Configured
  ['带宽']=Bandwidth
  ['常用操作']='Common actions'
  ['并复核当前内核的官方安装条件']='And review the official installation conditions of the current kernel'
  ['并跳过全部代理路径的']='and skip all proxy paths'
  ['应用配置并重启服务']='Apply configuration and restart service'
  ['开关']=Switch
  ['开头']=Beginning
  ['异常']=Error
  ['异常：本地']='Exception: local'
  ['异常：进程未运行']='Exception: Process is not running'
  ['当前']=current
  ['当前为']=Currently
  ['当前入口']='Current entrance'
  ['当前内核']='Current kernel'
  ['当前内核不会立即切换，现有服务会继续运行。']='The current core will not switch immediately and existing services will continue to run.'
  ['当前内核不支持加载']='The current kernel does not support loading'
  ['当前内核头文件并配置开机加载。']='The current kernel header file and configuration are loaded at boot.'
  ['当前内核支持安装']='The current kernel supports installation'
  ['当前内核未启用可加载模块（']='Loadable modules are not enabled in the current kernel ('
  ['当前内核缺少']='The current kernel is missing'
  ['当前显示']='Currently showing'
  ['当前核心的统计计数读取失败，未重置历史数据。']='Failed to read the statistics count of the current core and the historical data was not reset.'
  ['当前没有']='No current '
  ['当前版本']='Current version'
  ['当前状态']='Current status'
  ['当前环境无法安全安装']='The current environment cannot be installed safely'
  ['当前环境是容器，不能安全安装宿主机内核模块。']='The current environment is a container and the host kernel module cannot be safely installed.'
  ['当前系统不支持']='The current system does not support'
  ['当前脚本已是最新版本。']='The current script is the latest version.'
  ['当前落地']='Current egress'
  ['当前规则']='Current rules'
  ['当前运行内核']='Running kernel'
  ['当前运行内核的匹配头文件安装后仍不可用：']='The matching header files for the currently running kernel are still unavailable after installation:'
  ['当前运行内核的精确头文件安装失败：']='Installation of the exact header files for the currently running kernel failed:'
  ['当前运行进程不是']='The currently running process is not'
  ['当前配置']='Current configuration'
  ['待删除域名不能为空。']='The domain name to be deleted cannot be empty.'
  ['必填']=required
  ['必须以']='Must be'
  ['必须重启进入新内核，再运行']='You must reboot into the new kernel and then run'
  ['恢复来源']='restore source'
  ['恢复节点配置']='Restore node configuration'
  ['恢复配置']='Restore config'
  ['或']=or
  ['或控制字符。']='or control characters.'
  ['或留空使用']='Or leave it blank to use'
  ['或输入']='or enter'
  ['打开自适应订阅']='Turn on adaptive subscription'
  ['执行']=Executed
  ['拒绝安装。']='Installation refused.'
  ['拒绝导入。']='Import refused.'
  ['拒绝自动迁移。']='Reject automatic migration.'
  ['拒绝覆盖。']='Deny coverage.'
  ['指令。']=instructions.
  ['指向']='point to'
  ['指定格式']='Specify format'
  ['探测未成功，配置未变更。']='The detection was unsuccessful and the configuration has not been changed.'
  ['控制中心']='Control center'
  ['推荐使用。扫码或打开链接，自动匹配客户端格式。']='Recommended. Scan the QR code or open the link to automatically match the client format.'
  ['提醒']=Warning
  ['握手正常']='Handshake normal'
  ['支持。']=Support.
  ['文件或目录；']='file or directory;'
  ['新值格式：']='Format: '
  ['新值格式：http']='Format: http'
  ['新内核与匹配头文件']='New kernel with matching header files'
  ['新内核与匹配头文件已安装。']='The new kernel with matching header files is installed.'
  ['新内核与匹配头文件？']='New kernel with matching headers?'
  ['新内核尚未启用；请稍后重启，再安装']='The new kernel has not been enabled yet; please reboot later and install again.'
  ['新内核或匹配头文件安装失败。']='Installation of new kernel or matching header files failed.'
  ['新增分类']='Add new category'
  ['新增域名']='Add domain name'
  ['新增域名不能为空。']='The new domain name cannot be empty.'
  ['新旧目录中的项目文件内容不同，拒绝覆盖：']='The contents of the project files in the old and new directories are different and overwriting is refused:'
  ['新服务尚未全部启动，已保留旧服务文件以便排查。']='The new services have not all been started yet, and the old service files have been retained for troubleshooting.'
  ['新的节点参数']='New node parameters'
  ['新目录中的项目文件类型异常，拒绝迁移：']='The project file type in the new directory is abnormal and migration is refused:'
  ['无']=None
  ['无响应，请检查当前核心配置与监听端口。']='No response, please check the current core configuration and listening port.'
  ['无效']=Invalid
  ['无效。']=Invalid.
  ['无效选项']='Invalid choice'
  ['无效选项（请输入']='Invalid option (please enter'
  ['无效选项：']='Invalid choice: '
  ['无法使用']='Not available'
  ['无法初始化']='Unable to initialize'
  ['无法初始化流量数据库。']='Unable to initialize traffic database.'
  ['无法启动']='Unable to start'
  ['无法安装当前内核的精确头文件，未继续安装']='Unable to install the exact header files for the current kernel, installation did not continue'
  ['无法把']='Can'"'"'t put it'
  ['无法构建']='Unable to build'
  ['无法确定']='Unable to determine'
  ['无法确认']='Unable to confirm'
  ['无法自动安装：当前系统没有']='Unable to install automatically: The current system does not have'
  ['无法获取']='Unable to obtain'
  ['无法识别']=Unrecognized
  ['无法识别系统，仅支持']='Unable to recognize the system, only supports'
  ['无法读取']='Unable to read'
  ['无法读取备份归档目录。']='Unable to read backup archive directory.'
  ['无法通过']='Unable to pass'
  ['无法重置流量统计。']='Unable to reset traffic statistics.'
  ['旧']=old
  ['旧目录中的项目文件类型异常，拒绝迁移：']='The project file type in the old directory is abnormal and migration is refused:'
  ['旧项目']='old project'
  ['旧项目路径类型异常，拒绝自动迁移：']='The old project path type is abnormal and automatic migration is refused:'
  ['时仅支持']='only supports'
  ['是']=yes
  ['暂不可用']=Unavailable
  ['暂不可读']='Not readable yet'
  ['更新']=update
  ['更新后验证失败，正在自动回滚。']='Verification failed after update and is being automatically rolled back.'
  ['最新备份']='latest backup'
  ['最新安装脚本']='Latest installation script'
  ['最新版本']='Latest version'
  ['最近采集']='Recently collected'
  ['服务']=service
  ['服务与功能状态']='Services / Features'
  ['服务器尚未加载']='The server has not loaded yet'
  ['服务器重启请求失败，请手动执行']='Server restart request failed, please perform it manually'
  ['服务或端口异常']='Service or port exception'
  ['服务操作']='Service actions'
  ['服务文件一致']='Service files are consistent'
  ['服务文件不存在']='Service file does not exist'
  ['服务文件未同步']='Service files are not synchronized'
  ['服务状态']='Service status'
  ['服务管理']=Services
  ['未加载']='not loaded'
  ['未变更']=unchanged
  ['未启用']=Disabled
  ['未安装']='Not installed'
  ['未安装或未加载']='Not installed or not loaded'
  ['未安装新内核']='No new kernel installed'
  ['未执行任何变更。']='No changes were performed.'
  ['未找到']='not found'
  ['未找到节点：']='Node not found:'
  ['未提供']='Not provided'
  ['未清理旧']='Not cleaning old'
  ['未监听。']='Not listening.'
  ['未知']=Unknown
  ['未知参数。可用参数：']='Unknown parameters. Available parameters:'
  ['未知安装参数：']='Unknown installation parameters:'
  ['未知安装模式：']='Unknown installation mode:'
  ['未知页面提示模式：']='Unknown page prompt mode:'
  ['未确认']=Unconfirmed
  ['未确认出口']='Unconfirmed export'
  ['未能验证公网出口，请检查网络或']='Unable to verify public network exit, please check the network or'
  ['未运行']='Not running'
  ['未运行。']='Not running.'
  ['未运行或无法读取进程信息']='Not running or cannot read process information'
  ['未选择需要更新的组件。']='No components selected for update.'
  ['未通过']=failed
  ['未配置']='Not configured'
  ['本地']=local
  ['本地代理端口无效。']='The local proxy port is invalid.'
  ['本地安装']='Local installation'
  ['本地端口']='Local port'
  ['本地端口冲突']='local port conflict'
  ['本地端口无效']='Invalid local port'
  ['本次不会继续安装']='The installation will not continue this time'
  ['权限']=Permissions
  ['来源：']=Source:
  ['构建标签。']='Build tags.'
  ['架构。']=architecture.
  ['架构没有受支持的内核元包升级引导。']='The architecture does not have a supported kernel metapackage upgrade boot.'
  ['查询失败']='Query failed'
  ['标签']=Label
  ['校验失败。']='Verification failed.'
  ['核心']=core
  ['核心不存在。']='The core doesn'"'"'t exist.'
  ['核心服务已重启']='Core services have been restarted'
  ['核心服务重启']='Core service restart'
  ['核心类型无效。']='The core type is invalid.'
  ['格式不正确。']='The format is incorrect.'
  ['格式检查未通过']='Format check failed'
  ['检测到']=detected
  ['检测到两份内容不同的旧配置，拒绝自动合并。']='Two old configurations with different contents were detected and automatic merging was refused.'
  ['检测到旧版完整备份，仅恢复其中的节点配置，不替换脚本或核心。']='An old full backup is detected and only the node configuration from it is restored without replacing scripts or core.'
  ['检测到旧组合项目完整备份，仅恢复其中的节点配置。']='A full backup of an old portfolio project is detected and only the node configuration within it is restored.'
  ['检测到旧项目完整备份，仅恢复其中的节点配置。']='A full backup of an old project is detected and only the node configuration within it is restored.'
  ['检测到旧项目节点备份，仅恢复其中的节点配置。']='An old project node backup is detected and only the node configuration within it is restored.'
  ['检测到未知命令链接']='Unknown command link detected'
  ['检测到未知旧目录符号链接']='Unknown old directory symlink detected'
  ['检测到本项目旧版']='An old version of this project was detected'
  ['检测到现有']='Existing detected'
  ['检测到非本项目服务']='Non-project services detected'
  ['检测到非项目命令']='Non-project command detected'
  ['模块']=module
  ['模块。']=module.
  ['模块包']='module package'
  ['模块包结构无效。']='Invalid module package structure.'
  ['模块将保留。']='Modules will be retained.'
  ['模块已加载']='module loaded'
  ['模块未能加载。']='Module failed to load.'
  ['模块状态']='module status'
  ['模块，请先执行“安装']='module, please first execute "Install'
  ['次']=times
  ['正在停止']=Stopping
  ['正在创建节点配置备份']='Creating node configuration backup'
  ['正在刷新']=Refreshing
  ['正在启动']=Starting
  ['正在安装']=Installing
  ['正在安装已固定并校验的']='Installing fixed and verified'
  ['正在恢复修改前配置']='Restoring configuration before modification'
  ['正在恢复节点配置']='Restoring node configuration'
  ['正在校验备份归档']='Verifying backup archive'
  ['正在获取最新安装脚本']='Getting the latest installation script'
  ['正在配置']=Configuring
  ['正在重启服务器，']='Restarting server,'
  ['正在重启核心服务']='Restarting core services'
  ['正常']=Healthy
  ['每分钟']='per minute'
  ['每次只能删除一个分类。']='Only one category can be deleted at a time.'
  ['每次只能删除一个域名。']='Only one domain name can be deleted at a time.'
  ['没有']=None
  ['没有可用的后续节点端口。']='No subsequent node ports are available.'
  ['注册删除失败。']='Registration deletion failed.'
  ['注册，已取消启用。']='Registration, deactivated.'
  ['注册？']='Register?'
  ['流量数据库正忙，请稍后重试。']='The traffic database is busy, please try again later.'
  ['流量统计']=Traffic
  ['流量统计定时器']='Traffic timer'
  ['流量统计定时器未运行。']='The traffic statistics timer is not running.'
  ['流量统计定时器运行正常。']='The traffic statistics timer is running normally.'
  ['流量统计已刷新。']='Traffic statistics have been refreshed.'
  ['流量统计已重置']='Traffic statistics have been reset'
  ['流量统计采集']='Traffic statistics collection'
  ['流量账本。']='Traffic ledger.'
  ['流量账本失败。']='Traffic ledger failed.'
  ['流量账本正忙。']='The traffic ledger is busy.'
  ['流量采集']='Traffic collector'
  ['添加分类']='Add category'
  ['添加域名']='Add domain name'
  ['添加节点']='Add node'
  ['版本。']=version.
  ['版本校验失败。']='Version verification failed.'
  ['状态']=Status
  ['状态报告']='Status report'
  ['用户名']=Username
  ['用户运行此脚本。']='User runs this script.'
  ['用法：']=Usage:
  ['留空为']='Leave blank for'
  ['的']=of
  ['的整数。']=integer.
  ['监听端口']='listening port'
  ['目录或']='directory or'
  ['目标']=target
  ['目标。']=target.
  ['目标版本']='Target version'
  ['目标网址无效：']='Invalid destination URL:'
  ['直连']='direct connection'
  ['直连出口']='Directly connected to the outlet'
  ['直连出站']='Direct egress'
  ['省略端口时使用']='Used when port is omitted'
  ['确认']=Confirm
  ['确认停用']='Confirm deactivation'
  ['确认删除并重新注册旧']='Confirm deletion and re-register the old'
  ['确认删除节点']='Confirm node deletion'
  ['确认卸载：']='Confirm uninstall:'
  ['确认同时卸载']='Confirm to uninstall at the same time'
  ['确认启动第三方系统脚本？']='Are you sure you want to start the third-party system script?'
  ['确认安装']='Confirm installation'
  ['确认安装或更新']='Confirm installation or update'
  ['确认更新']='Confirm update'
  ['确认重置全部历史流量？']='Are you sure to reset all historical traffic?'
  ['空']=empty
  ['立即重启服务器？']='Restart the server now?'
  ['端口']=Port
  ['端口不能与']='Port cannot be used with'
  ['端口冲突：']='Port conflict:'
  ['端口无效。']='The port is invalid.'
  ['端口相同。']='The ports are the same.'
  ['端口范围必须为']='Port range must be '
  ['端口过大，无法为全部节点顺延监听端口。']='The port is too large and the listening port cannot be postponed for all nodes.'
  ['第三方']='third party'
  ['第三方工具']='Third party tools'
  ['第三方脚本不属于']='Third party scripts are not'
  ['等通用工具？可能被其他程序使用']='Waiting for a general tool? May be used by other programs'
  ['简体中文']='简体中文'
  ['管理命令']=Commands
  ['系统']=system
  ['系统内存']='system memory'
  ['系统工具']='System tools'
  ['系统未变更']='The system has not changed'
  ['系统环境']=System
  ['系统维护']=Maintenance
  ['系统缺少']='System is missing'
  ['累计值']='Cumulative value'
  ['组件已回滚到更新前版本，请查看']='The component has been rolled back to the pre-update version, please check'
  ['组件更新']='Update components'
  ['组件版本']=Components
  ['结尾。']='The end.'
  ['统计']=statistics
  ['统计操作']='Traffic actions'
  ['统计数据未变更']='Statistics unchanged'
  ['统计状态']='Statistical status'
  ['统计起点']='statistical starting point'
  ['缺少']=Missing
  ['缺少 brutal 内核模块']='Missing brutal kernel module'
  ['缺少匹配头文件，且']='A matching header file is missing, and'
  ['缺少配置事务快照。']='Configuration transaction snapshot is missing.'
  ['缺少项目所有权标记，拒绝备份。']='Missing project ownership tag, backup rejected.'
  ['缺少项目所有权标记，拒绝恢复节点配置。']='Missing project ownership tag, refusing to restore node configuration.'
  ['缺少项目所有权标记，拒绝自动卸载；请人工核对']='Project ownership tag is missing, automatic uninstallation is refused; please check manually'
  ['网络出站']=Egress
  ['脚本已更新，正在使用新版继续安装。']='The script has been updated and the installation is continuing with the new version.'
  ['脚本统计']='Script runs'
  ['自动使用']='automatically used'
  ['自动适配']=Adaptive
  ['自适应']=Adaptive
  ['自适应订阅']='adaptive subscription'
  ['至少必须保留一个节点。']='At least one node must be retained.'
  ['至少需要一个域名或']='Requires at least one domain name or'
  ['节点']=node
  ['节点代理']='Node proxy'
  ['节点代理无效']='Node agent is invalid'
  ['节点代理格式无效']='Node agent format is invalid'
  ['节点列表']='Node list'
  ['节点协议']=Protocol
  ['节点协议无效']='Node protocol is invalid'
  ['节点参数']='Node parameters'
  ['节点已修改：']='Node has been modified:'
  ['节点已删除：']='Node deleted:'
  ['节点已添加：']='Node added:'
  ['节点文件']='Node file'
  ['节点文件不存在，请先安装。']='The node file does not exist, please install it first.'
  ['节点标签']=Label
  ['节点标签、路径或端口重复。']='Duplicate node label, path, or port.'
  ['节点标签已存在：']='Node label already exists:'
  ['节点标签无效：']='Invalid node label:'
  ['节点标签无效：不能为空、首尾不能留空，且不能包含']='The node label is invalid: it cannot be empty, the beginning and the end cannot be left blank, and it cannot contain'
  ['节点标签：']='Node label:'
  ['节点概览']=Nodes
  ['节点端口与']='Node port and'
  ['节点端口与流量统计']='Node port and traffic statistics'
  ['节点端口仍被未知进程占用。为避免终止第三方服务，安装已停止。']='The node port is still occupied by an unknown process. To avoid terminating third-party services, installation has been stopped.'
  ['节点端口错误：']='Node port error:'
  ['节点管理']=Nodes
  ['节点落地']=Egress
  ['节点落地 IP']='Node egress IP'
  ['节点订阅']=Subscriptions
  ['节点配置']='Node config'
  ['节点配置不存在：']='Node configuration does not exist:'
  ['节点配置为空：']='Node configuration is empty:'
  ['节点配置备份完成：']='Node configuration backup completed:'
  ['节点配置字段数量错误。']='The number of node configuration fields is wrong.'
  ['节点配置恢复失败，已回滚到恢复前状态。']='The node configuration failed to be restored and has been rolled back to the state before restoration.'
  ['节点配置恢复失败，正在回滚。']='Node configuration recovery failed and is being rolled back.'
  ['节点配置恢复完成：']='Node configuration restoration is completed:'
  ['范围']=Scope
  ['菜单']=Menu
  ['行包含未知字段：']='Row contains unknown fields:'
  ['行格式无效，仅支持']='Invalid row format, only supported'
  ['行的单引号值无效。']='The row'"'"'s single quote value is invalid.'
  ['行的双引号值无效。']='The line'"'"'s double-quoted value is invalid.'
  ['行的未引用值不能包含空格或']='The unquoted value of a row cannot contain spaces or'
  ['被']=Be
  ['要删除的分类：']='Categories to be deleted:'
  ['要删除的域名：']='Domain name to be deleted:'
  ['规则']=Rules
  ['规则操作']='Rule operation'
  ['规则集，旧配置未改动。']='Rule set, old configuration unchanged.'
  ['订阅']=Subscription
  ['订阅中心']='Subscription Center'
  ['订阅中心页面过长，拒绝写入可能导致']='The subscription center page is too long, and refusal to write may result in'
  ['订阅链接']='Subscription link'
  ['订阅面板']='Subscription panel'
  ['设为']='set to'
  ['设置']=Set
  ['诊断完成']='Diagnostics complete'
  ['诊断结果']='Diagnostic result'
  ['语法检查失败。']='Syntax check failed.'
  ['语言设置']=Language
  ['语言设置已保存']='Language preference saved'
  ['请使用']='Please use'
  ['请先启用']='Please enable first'
  ['请先执行安装']='Please install first'
  ['请同步确认']='Please confirm simultaneously'
  ['请执行项目安装更新依赖。']='Please execute the project to install and update dependencies.'
  ['请确认']='Please confirm'
  ['请输入']='Please enter'
  ['请输入有效域名']='Please enter a valid domain name'
  ['请输入标准']='Please enter criteria'
  ['请选择节点落地']='Please select the node landing'
  ['请选择：']='Select: '
  ['路径']=Path
  ['路径冲突']='path conflict'
  ['路径无效']='Invalid path'
  ['路由分流']=Routing
  ['软件包卸载失败，请手工检查。']='Uninstallation of the software package failed, please check manually.'
  ['软件包索引']='Package index'
  ['软件包索引更新失败，无法复核']='Package index update failed and cannot be reviewed'
  ['软件包索引更新失败，未安装新内核。']='Package index update failed, new kernel not installed.'
  ['软件源。']='Software source.'
  ['软件源不可用；请检查系统版本和网络后重试。']='The software source is unavailable; please check the system version and network and try again.'
  ['软件源并安装']='Software source and installation'
  ['软件源签名密钥下载失败。']='Software source signing key download failed.'
  ['软件源签名密钥指纹校验失败。']='Software source signature key fingerprint verification failed.'
  ['轻量版仅支持使用']='The lightweight version only supports the use of'
  ['输入']=input
  ['运行中']=Running
  ['运行内存']=Memory
  ['运行日志']='Runtime logs'
  ['运行检查']='run check'
  ['运行正常。']='It works fine.'
  ['运行状态']='Runtime status'
  ['运行观测']=Monitoring
  ['运行诊断']=Diagnostics
  ['近期错误日志']='Recent errors'
  ['返回']=Back
  ['返回了无法解析的全局计数。']='An unresolved global count was returned.'
  ['进程内存不可读']='Process memory is not readable'
  ['连接即将断开']='The connection is about to be lost'
  ['连接恢复后，请重新运行']='Once the connection is restored, run again'
  ['退出']=Exit
  ['退出脚本']=Exit
  ['选择']=Choose
  ['选择域名连接的优先出口；目标不支持时使用另一地址族。']='Select the preferred exit for domain name connections; use another address family if the target does not support it.'
  ['选择节点']='Select node'
  ['选择适合客户端的订阅方式。']='Choose a subscription method that suits your client.'
  ['选项无效']='Invalid choice'
  ['逗号分隔；']='comma separated;'
  ['部分进程不可读']='Some processes are unreadable'
  ['部分通用工具卸载失败，请手工检查。']='Uninstallation of some common tools failed, please check manually.'
  ['配置']=Config
  ['配置。']=configuration.
  ['配置中心']=Configuration
  ['配置关闭']='Configuration off'
  ['配置失败的']='Configuration failed'
  ['配置导入']='Import config'
  ['配置导入已完成']='Configuration import completed'
  ['配置已生效']='Configuration has taken effect'
  ['配置文件不能同时使用']='Configuration files cannot be used at the same time'
  ['配置文件中的']='in the configuration file'
  ['配置文件必须是可读的普通文件，且不能是符号链接：']='The configuration file must be a readable ordinary file and cannot be a symbolic link:'
  ['配置文件第']='Configuration file no.'
  ['配置文件绝对路径：']='Configuration file absolute path:'
  ['配置文件超过']='Profile exceeds'
  ['配置文件路径不能为空。']='The configuration file path cannot be empty.'
  ['配置无效。']='Invalid configuration.'
  ['配置未变更']='Configuration unchanged'
  ['配置未生效']='Configuration does not take effect'
  ['配置检查']='Configuration check'
  ['配置维护']=Configuration
  ['配置输入']='Configuration input'
  ['配置验证失败']='Configuration verification failed'
  ['重启会立即中断']='Restart will interrupt immediately'
  ['重启后未运行。']='Not running after restarting.'
  ['重启后系统才会使用新内核。']='The system will use the new kernel only after restarting.'
  ['重启服务']='Restart service'
  ['重启核心服务']='Restart core services'
  ['重启确认']='Restart confirmation'
  ['重启范围']='Restart scope'
  ['重新注册。']='Register again.'
  ['重置统计']='Reset traffic'
  ['错误']=Error
  ['需注意']='Need to pay attention'
  ['项异常']='Item exception'
  ['项探测超时']='Item detection timeout'
  ['项目卸载']='Uninstall project'
  ['项目安装']='Install project'
  ['项目文件']='project files'
  ['项目服务']='Project services'
  ['项目未变更']='The project has not changed'
  ['项目版本']='Project version'
  ['项目目录内仅允许使用默认备份目录']='Only the default backup directory is allowed in the project directory'
  ['项目目录解析结果异常，拒绝递归删除：']='The project directory parsing result is abnormal and recursive deletion is refused:'
  ['项目管理']=Project
  ['项目配置']='Project configuration'
  ['项目配置与统计数据']='Project configuration and statistics'
  ['顺延后的节点端口会占用']='The node port after postponement will occupy'
  ['顺延后的节点端口会占用流量统计']='The postponed node port will occupy traffic statistics'
  ['风险提示']='Risk warning'
  ['默认']=Default
  ['默认保留']='Keep by default'
  ['默认目录']='default directory'
  ['默认）']='default)'
)
ui_text() {
  local LC_ALL=C.UTF-8 rest="$*" output="" prefix part translated
  if [[ "${UI_LANGUAGE:-zh}" == zh ]]; then builtin printf '%s' "$rest"; return; fi
  # Translate fixed Chinese UI fragments; leave dynamic ASCII values untouched.
  while [[ "$rest" =~ ^([^一-龥]*)([一-龥][一-龥，。；：、（）“”？]*)(.*)$ ]]; do
    prefix="${BASH_REMATCH[1]}"; part="${BASH_REMATCH[2]}"; rest="${BASH_REMATCH[3]}"
    translated="${UI_EN[$part]:-$part}"
    [[ -z "$prefix" || "$prefix" != *[A-Za-z0-9] ]] || prefix+=" "
    [[ -z "$rest" || "$rest" != [A-Za-z0-9]* ]] || translated+=" "
    output+="${prefix}${translated}"
  done
  output="${output}${rest}"
  output="${output//：/: }"; output="${output//（/(}"; output="${output//）/)}"
  output="${output//；/; }"; output="${output//，/, }"; output="${output//。/.}"
  builtin printf '%s' "$output"
}
ui_printf() {
  local format
  format="$(ui_text "$1")"; shift
  builtin printf "$format" "$@"
}

ui_line() {
  local char="${1:--}"
  UI_LAST_WAS_LINE=1
  printf '%s%*s%s\n' "$C_BRIGHT_BLUE" "$UI_WIDTH" '' "$C_RESET" | tr ' ' "$char"
}
ui_ok() { printf '%s✓ %s%s\n' "$C_BRIGHT_GREEN" "$(ui_text "$*")" "$C_RESET"; }
ui_warn() { printf '%s! %s%s\n' "$C_BRIGHT_YELLOW" "$(ui_text "$*")" "$C_RESET"; }
ui_err() { printf '%s✗ %s%s\n' "$C_ERR_RED" "$(ui_text "$*")" "$C_ERR_RESET" >&2; }
ui_info() { printf '%s• %s%s\n' "$C_BRIGHT_CYAN" "$(ui_text "$*")" "$C_RESET"; }
green() { ui_ok "$@"; }
yellow() { ui_warn "$@"; }
red() { ui_err "$@"; }
info() { ui_info "$@"; }
display_width() {
  local LC_ALL=C.UTF-8 text="$1" character code width=0
  while [[ -n "$text" ]]; do
    character="${text:0:1}"; text="${text:1}"
    printf -v code '%d' "'$character"
    if (( (code >= 0x0300 && code <= 0x036f) || (code >= 0xfe00 && code <= 0xfe0f) )); then
      continue
    elif (( (code >= 0x1100 && code <= 0x115f) || code == 0x2329 || code == 0x232a ||
      (code >= 0x2e80 && code <= 0xa4cf && code != 0x303f) ||
      (code >= 0xac00 && code <= 0xd7a3) || (code >= 0xf900 && code <= 0xfaff) ||
      (code >= 0xfe10 && code <= 0xfe19) || (code >= 0xfe30 && code <= 0xfe6f) ||
      (code >= 0xff00 && code <= 0xff60) || (code >= 0xffe0 && code <= 0xffe6) ||
      (code >= 0x1f300 && code <= 0x1faff) || (code >= 0x20000 && code <= 0x3fffd) )); then
      width=$((width + 2))
    else width=$((width + 1)); fi
  done
  printf '%s' "$width"
}
pad_right() {
  local text="$1" target="$2" width pad
  width="$(display_width "$text")"
  pad=$((target - width))
  ((pad < 0)) && pad=0
  printf '%s%*s' "$text" "$pad" ''
}
pad_left() {
  local text="$1" target="$2" width pad
  width="$(display_width "$text")"
  pad=$((target - width))
  ((pad < 0)) && pad=0
  printf '%*s%s' "$pad" '' "$text"
}
clip_text() {
  local text="$1" target="$2" clipped="$1"
  if (( $(display_width "$text") <= target )); then
    printf '%s' "$text"
    return
  fi
  while [[ -n "$clipped" ]] && (( $(display_width "$clipped") > target - 1 )); do
    clipped="${clipped:0:${#clipped}-1}"
  done
  printf '%s~' "$clipped"
}
fit_text() {
  local text target
  text="$(clip_text "$1" "$2")"
  target="$2"
  pad_right "$text" "$target"
}
ui_page() {
  local title="$(ui_text "$1")" mode="${2:-none}" hint="" hint_text="" title_width hint_width padding default_text exit_text
  case "$mode" in
    main) hint_text="退出" ;;
    back) hint_text="返回" ;;
    cancel) hint_text="取消" ;;
    default) hint="Enter · 默认 | 0 · 退出" ;;
    none) ;;
    *) die "未知页面提示模式：${mode}" ;;
  esac
  hint_text="$(ui_text "$hint_text")"; hint="$(ui_text "$hint")"
  default_text="$(ui_text 默认)"; exit_text="$(ui_text 退出)"
  [[ -z "$hint_text" ]] || hint="0 · ${hint_text}"
  printf '\n%s%s◆ %s%s' "$C_BOLD" "$C_BRIGHT_MAGENTA" "$title" "$C_RESET"
  if [[ -n "$hint" ]]; then
    title_width="$(display_width "◆ $title")"
    hint_width="$(display_width "$hint")"
    padding=$((UI_WIDTH - title_width - hint_width))
    if ((padding >= 2)); then
      if [[ "$mode" == "default" ]]; then
        printf '%*s%sEnter%s · %s%s%s | %s0%s · %s%s%s\n' "$padding" '' \
          "$C_BRIGHT_YELLOW" "$C_RESET" "$C_BRIGHT_WHITE" "$default_text" "$C_RESET" \
          "$C_BRIGHT_YELLOW" "$C_RESET" "$C_BRIGHT_WHITE" "$exit_text" "$C_RESET"
      else
        printf '%*s%s0%s · %s%s\n' "$padding" '' "$C_BRIGHT_YELLOW" "$C_BRIGHT_WHITE" \
          "$hint_text" "$C_RESET"
      fi
    else
      if [[ "$mode" == "default" ]]; then
        printf '\n  %sEnter%s · %s%s%s | %s0%s · %s%s%s\n' \
          "$C_BRIGHT_YELLOW" "$C_RESET" "$C_BRIGHT_WHITE" "$default_text" "$C_RESET" \
          "$C_BRIGHT_YELLOW" "$C_RESET" "$C_BRIGHT_WHITE" "$exit_text" "$C_RESET"
      else
        printf '\n  %s0%s · %s%s\n' "$C_BRIGHT_YELLOW" "$C_BRIGHT_WHITE" "$hint_text" "$C_RESET"
      fi
    fi
  else
    printf '\n'
  fi
  ui_line
}
brand() {
  local mode="${2:-none}"
  case "$mode" in main|back|cancel) mode=default ;; esac
  ui_page "$1" "$mode"
  show_script_runs
}
system_summary() {
  local os="Linux" arch kernel
  if [[ -r /etc/os-release ]]; then
    os="$(
      # shellcheck disable=SC1091
      source /etc/os-release
      printf '%s' "${NAME:-${PRETTY_NAME:-Linux}}${VERSION_ID:+ $VERSION_ID}"
    )"
  fi
  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) arch="$(uname -m)" ;;
  esac
  kernel="$(uname -r)"
  printf '%s · %s · Kernel %s' "$os" "$arch" "${kernel%%[+-]*}"
}
geojs_field() {
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg key "$2" '.[$key] // empty' <<<"$1" 2>/dev/null || true
  else
    # 首次安装尚无 jq；GeoJS 是平面 JSON，兼容紧凑与多行响应。
    tr '\n' ' ' <<<"$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
  fi
}
geojs_query() {
  local family="$1" source destination
  local -a bind=()
  destination=1.1.1.1
  [[ "$family" == 6 ]] && destination=2606:4700:4700::1111
  # 与 SBA 一样按地址族检测并绑定默认公网路由，排除环境代理。
  source="$(ip -"$family" route get "$destination" 2>/dev/null | awk '{for(i=1;i<NF;i++) if($i=="src") {print $(i+1); exit}}' || true)"
  [[ -z "$source" ]] || bind=(--interface "$source")
  curl -"$family"fsS --noproxy '*' "${bind[@]}" --connect-timeout 2 --max-time 4 \
    --retry 1 --retry-delay 0 --retry-all-errors https://get.geojs.io/v1/ip/geo.json 2>/dev/null || true
}
detect_public_ips() {
  [[ "${PUBLIC_IPS_DETECTED:-0}" == 1 ]] && return 0
  PUBLIC_IPV4_JSON="$(geojs_query 4)"
  PUBLIC_IPV6_JSON="$(geojs_query 6)"
  PUBLIC_IPV4="$(geojs_field "$PUBLIC_IPV4_JSON" ip)"
  PUBLIC_IPV6="$(geojs_field "$PUBLIC_IPV6_JSON" ip)"
  [[ "$PUBLIC_IPV4" =~ ^[0-9]+(\.[0-9]+){3}$ ]] && valid_ipv4 "$PUBLIC_IPV4" || PUBLIC_IPV4=""
  [[ "$PUBLIC_IPV6" == *:* && "$PUBLIC_IPV6" != :: && "$PUBLIC_IPV6" != ::1 ]] &&
    valid_endpoint_host "$PUBLIC_IPV6" || PUBLIC_IPV6=""
  PUBLIC_IPS_DETECTED=1
}
direct_strategy() {
  if [[ -n "$PUBLIC_IPV4" && -z "$PUBLIC_IPV6" ]]; then printf ipv4_only; return
  elif [[ -z "$PUBLIC_IPV4" && -n "$PUBLIC_IPV6" ]]; then printf ipv6_only; return; fi
  case "${1:-}" in
    direct:ipv4) printf prefer_ipv4 ;;
    direct:ipv6) printf prefer_ipv6 ;;
    *) printf prefer_ipv4 ;;
  esac
}
select_node_egress() {
  local current="$1" choice default=4
  detect_public_ips
  [[ "$current" == direct:ipv6 || ( -z "$PUBLIC_IPV4" && -n "$PUBLIC_IPV6" ) ]] && default=6
  [[ -n "$PUBLIC_IPV4" || -n "$PUBLIC_IPV6" ]] || die "未能验证公网出口，请检查网络或 GeoJS 后重试。"
  key_value "IPv4 出口" "${PUBLIC_IPV4:-没有}"
  key_value "IPv6 出口" "${PUBLIC_IPV6:-没有}"
  if [[ -n "$PUBLIC_IPV4" && -n "$PUBLIC_IPV6" ]]; then
    info "选择域名连接的优先出口；目标不支持时使用另一地址族。"
    read_input "直连出口 [4 IPv4 / 6 IPv6；${default}]：" choice
    is_exit_input "$choice" && return 1
    choice="${choice:-$default}"
    [[ "$choice" == 4 || "$choice" == 6 ]] || die "出口只能选择 4 或 6。"
  elif [[ -n "$PUBLIC_IPV4" ]]; then choice=4
  else choice=6; fi
  NODE_EGRESS="direct:ipv${choice}"
}
service_process_ids() {
  local unit="$1" group main base
  main="$(systemctl show "$unit" -p MainPID --value 2>/dev/null || true)"
  [[ "$main" =~ ^[1-9][0-9]*$ ]] && printf '%s\n' "$main"
  group="$(systemctl show "$unit" -p ControlGroup --value 2>/dev/null || true)"
  # 不读取根 cgroup，避免将整台 VPS 或其他服务统计为项目进程。
  [[ "$group" == /* && "$group" != / && "$group" != *..* ]] || return 0
  for base in "${CGROUP_ROOT:-/sys/fs/cgroup}" "${CGROUP_ROOT:-/sys/fs/cgroup}/systemd"; do
    [[ -d "$base$group" ]] || continue
    find "$base$group" -type f -name cgroup.procs -exec cat {} + 2>/dev/null || true
  done
}
traffic_timer_status() {
  if systemctl is-active --quiet "${TRAFFIC_TIMER}.timer" 2>/dev/null; then
    ui_printf '已启用 · 每分钟'
  else ui_printf '未启用 · 定时器已停止'; fi
}
is_direct_outbound() { [[ -z "$1" || "$1" == direct:ipv4 || "$1" == direct:ipv6 ]]; }
GEOJS_GEO_URL="https://get.geojs.io/v1/ip/geo.json"
public_ip_details() {
  local family="$1" json ip country asn organization
  [[ "$family" == "4" || "$family" == "6" ]] || return 2
  if [[ "${PUBLIC_IPS_DETECTED:-0}" == 1 ]]; then
    if [[ "$family" == 4 ]]; then json="${PUBLIC_IPV4_JSON:-}"; else json="${PUBLIC_IPV6_JSON:-}"; fi
  else
    json="$(geojs_query "$family")"
  fi
  json="$(tr '\n' ' ' <<<"$json")"
  [[ -n "$json" ]] || return 1
  if command -v jq >/dev/null 2>&1; then
    ip="$(jq -r '.ip // empty' <<<"$json" 2>/dev/null || true)"
    country="$(jq -r '.country_code // empty' <<<"$json" 2>/dev/null || true)"
    asn="$(jq -r '.asn // empty' <<<"$json" 2>/dev/null || true)"
    organization="$(jq -r '.organization_name // .organization // empty' <<<"$json" 2>/dev/null || true)"
  else
    ip="$(sed -n 's/.*"ip"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$json" | head -n 1)"
    country="$(sed -n 's/.*"country_code"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$json" | head -n 1)"
    asn="$(sed -n 's/.*"asn"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' <<<"$json" | head -n 1)"
    organization="$(sed -n 's/.*"organization_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$json" | head -n 1)"
    [[ -n "$organization" ]] || organization="$(sed -n 's/.*"organization"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' <<<"$json" | head -n 1)"
  fi
  if [[ "$family" == "4" ]]; then
    valid_ipv4 "$ip" || return 1
  else
    [[ "$ip" != :: && "$ip" != ::1 && "$ip" == *:* ]] && valid_endpoint_host "$ip" || return 1
  fi
  organization="$(sed -E 's/^AS[0-9]+[[:space:]]+//' <<<"$organization")"
  [[ "$asn" =~ ^[0-9]+$ ]] && asn="AS${asn}"
  printf '%s|%s|%s|%s' "$ip" "${country:-未知}" "${asn:-未知}" "${organization:-未知}"
}
public_ipv4_details() { public_ip_details 4; }
public_ipv6_details() { public_ip_details 6; }
public_node_egress_ip() {
  local family="${OUTBOUND_IP_FAMILY:-auto}" details=""
  case "$family" in
    ipv4) details="$(public_ipv4_details 2>/dev/null || true)" ;;
    ipv6) details="$(public_ipv6_details 2>/dev/null || true)" ;;
    auto)
      details="$(public_ipv4_details 2>/dev/null || true)"
      [[ -n "$details" ]] || details="$(public_ipv6_details 2>/dev/null || true)"
      ;;
    *) ;;
  esac
  if [[ -n "$details" ]]; then printf '%s' "${details%%|*}"
  else ui_printf '未知'
  fi
}
effective_outbound_ip_family() {
  case "${OUTBOUND_IP_FAMILY:-auto}" in
    ipv4) printf 'ipv4' ;;
    ipv6) printf 'ipv6' ;;
    auto)
      if public_ipv4_details >/dev/null 2>&1; then printf 'ipv4'
      elif public_ipv6_details >/dev/null 2>&1; then printf 'ipv6'
      else return 1
      fi
      ;;
    *) return 2 ;;
  esac
}
node_overview() {
  [[ -s "$NODES_CONFIG" ]] || { printf 'VLESS 0 · VMess 0 · Trojan 0'; return; }
  awk -F'|' '
    {protocols[$2]++}
    END {
      printf "VLESS %d · VMess %d · Trojan %d", protocols["vless"], protocols["vmess"], protocols["trojan"]
    }
  ' "$NODES_CONFIG"
}
control_panel() {
  local UI_LABEL_WIDTH=12
  printf '%s%s' "$C_BOLD" "$C_BRIGHT_CYAN"
  cat <<'EOF'
    ___                     _____ _             __
   /   |  _________ _____  / ___/(_)___  ____ _/ /_  ____  _  __
  / /| | / ___/ __ `/ __ \ \__ \/ / __ \/ __ `/ __ \/ __ \| |/_/
 / ___ |/ /  / /_/ / /_/ /___/ / / / / / /_/ / /_/ / /_/ />  <
/_/  |_/_/   \__, /\____//____/_/_/ /_/\__, /_.___/\____/_/|_|
            /____/                    /____/
EOF
  printf '%s\n' "$C_RESET"
  printf '%s%s%s  %sv%s%s · Argo Tunnel · Sing-box Core\n' \
    "$C_BOLD" "$C_BRIGHT_MAGENTA" "$PROJECT_NAME" "$C_BRIGHT_YELLOW" "$VERSION" "$C_RESET"
  key_value "功能特性" "WS/TLS · WARP · h2mux · TCP Brutal"
  key_value "系统环境" "$(system_summary)"
  show_script_runs
  ui_line
  UI_TIGHT_SECTION=1
}
service_status() {
  local service="$1"
  if ! systemctl list-unit-files "${service}.service" --no-legend 2>/dev/null |
    grep -q "^${service}.service"; then
    ui_printf '未安装'
  elif systemctl is-active --quiet "$service"; then
    ui_printf '已启用 · 运行中'
  elif systemctl is-enabled --quiet "$service" 2>/dev/null; then
    ui_printf '已启用 · 异常：进程未运行'
  else
    ui_printf '未启用 · 已停止'
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
    ui_printf '未启用 · 可选功能'
  elif systemctl is-active --quiet warp-svc 2>/dev/null &&
    ss -lntH "sport = :${WARP_PROXY_PORT}" 2>/dev/null | grep -q .; then
    ui_printf '已启用 · 运行中 · 127.0.0.1:%s' "$WARP_PROXY_PORT"
  else
    ui_printf '已启用 · 异常：本地 SOCKS5 不可用'
  fi
}
component_versions() {
  printf '%s %s · cloudflared %s' "$(core_label)" \
    "$(local_core_version 2>/dev/null || ui_printf '未安装')" \
    "$(local_cloudflared_version 2>/dev/null || ui_printf '未安装')"
}
component_version_value() {
  local core_version tunnel_version version_color
  core_version="$(local_core_version 2>/dev/null || ui_printf '未安装')"
  tunnel_version="$(local_cloudflared_version 2>/dev/null || ui_printf '未安装')"
  field_label "组件版本"
  printf '%sSing-box ' "$C_BRIGHT_WHITE"
  version_color="$C_BRIGHT_WHITE"
  [[ "$core_version" != [0-9]* ]] || version_color="$C_BRIGHT_YELLOW"
  printf '%s%s%s · cloudflared ' "$version_color" "$core_version" "$C_BRIGHT_WHITE"
  version_color="$C_BRIGHT_WHITE"
  [[ "$tunnel_version" != [0-9]* ]] || version_color="$C_BRIGHT_YELLOW"
  printf '%s%s%s\n' "$version_color" "$tunnel_version" "$C_RESET"
}
section() {
  if [[ "${UI_TIGHT_SECTION:-0}" == "1" || "${UI_LAST_WAS_LINE:-0}" == "1" ]]; then
    UI_TIGHT_SECTION=0
  else
    printf '\n'
  fi
  UI_LAST_WAS_LINE=0
  printf '%s%s▸ %s%s\n' "$C_BOLD" "$C_BRIGHT_BLUE" "$(ui_text "$*")" "$C_RESET"
}
subsection() { section "$*"; }
field_label() {
  printf '%s' "$C_BRIGHT_CYAN"
  pad_right "$(ui_text "$1")" "$UI_LABEL_WIDTH"
  printf '%s  ' "$C_RESET"
}
field_text() { printf '%s%s%s\n' "$2" "$1" "$C_RESET"; }
key_value() {
  local value value_color="$C_BRIGHT_WHITE"
  if [[ "$2" == /* ]]; then value="$2"; else value="$(ui_text "$2")"; fi
  field_label "$1"
  field_text "$value" "$value_color"
}
ip_value() {
  local value
  value="$(ui_text "$2")"
  field_label "$1"
  field_text "$value" "$C_BRIGHT_MAGENTA"
}
endpoint_value() {
  local label="$1" host="$2" port="$3" color="$C_BRIGHT_WHITE" display_host="$2"
  [[ "$host" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ || "$host" =~ ^[0-9A-Fa-f:]+$ ]] && color="$C_BRIGHT_MAGENTA"
  [[ "$host" == *:* && "$host" != \[*\] ]] && display_host="[${host}]"
  field_label "$label"
  printf '%s%s:%s%s\n' "$color" "$display_host" "$port" "$C_RESET"
}
state_value() {
  local color="$C_BRIGHT_YELLOW" value="$2"
  case "$2" in
    *异常*|*错误*|*无效*|不可用*|未运行*|失败*|*Error*|*Invalid*|*Unavailable*|*Failed*|*Not\ running*) color="$C_BRIGHT_RED" ;;
    已启用*|运行中*|已通过*|已配置|Enabled*|Running*|Passed*|Configured) color="$C_BRIGHT_GREEN" ;;
    未配置*|未启用*|已停止*|未安装*|需注意*) color="$C_BRIGHT_YELLOW" ;;
  esac
  if [[ "$1" == "节点概览" ]]; then
    color="$C_BRIGHT_MAGENTA"
  fi
  value="$(ui_text "$value")"
  field_label "$1"
  field_text "$value" "$color"
}
link_value() {
  field_label "$1"
  printf '%s%s%s%s\n' "$C_BRIGHT_WHITE" "$C_UNDERLINE" "$2" "$C_RESET"
}
prompt() { printf '%s%s› %s%s' "$C_BOLD" "$C_BRIGHT_MAGENTA" "$(ui_text "$*")" "$C_RESET"; }
read_choice() {
  prompt "$1"
  IFS= read -r REPLY
  REPLY="${REPLY%$'\r'}"
  [[ -n "$REPLY" ]] || REPLY=0
}
read_input() { prompt "$1"; IFS= read -r "$2"; printf -v "$2" '%s' "${!2%$'\r'}"; [[ "${!2}" != 0 ]] || exit 0; }
is_exit_input() {
  case "${1:-}" in
    0) exit 0 ;;
    *) return 1 ;;
  esac
}
is_confirmed() { [[ "${1:-}" =~ ^[Yy]$ ]]; }
return_notice() { :; }

cancel_config_change() {
  [[ -n "${CONFIG_SNAPSHOT:-}" && -d "$CONFIG_SNAPSHOT" ]] && rm -rf "$CONFIG_SNAPSHOT"
  unset CONFIG_SNAPSHOT
  yellow "已取消修改 · 配置未变更"
}
cleanup_config_snapshot() {
  local snapshot="${CONFIG_SNAPSHOT:-}"
  [[ -n "$snapshot" && -d "$snapshot" ]] && rm -rf -- "$snapshot"
  return 0
}
trap cleanup_config_snapshot EXIT
menu_item() {
  local number_color="$C_BRIGHT_YELLOW"
  printf '  %s%2s%s  %s' "$number_color" "$1" "$C_RESET" "$C_BRIGHT_WHITE"
  pad_right "$(ui_text "$2")" 28
  printf '%s%s%s%s\n' "$C_RESET" "$C_BRIGHT_CYAN" "${3:+[$3]}" "$C_RESET"
}
menu_hint() {
  printf '  %s•%s %s%s%s\n' "$C_BRIGHT_CYAN" "$C_RESET" "$C_DIM" "$(ui_text "$*")" "$C_RESET"
}
protocol_label() {
  case "$1" in
    vless) printf 'VLESS' ;;
    vmess) printf 'VMess' ;;
    trojan) printf 'Trojan' ;;
    *) printf '%s' "$1" ;;
  esac
}

node_type_label() {
  case "$1" in
    vless) printf 'VLESS+WS+TLS' ;;
    vmess) printf 'VMess+WS+TLS' ;;
    trojan) printf 'Trojan+WS+TLS' ;;
    *) printf '%s' "$1" ;;
  esac
}
valid_node_tag() {
  local value="$1"
  [[ -n "$value" && $(display_width "$value") -le 48 ]] || return 1
  [[ "$value" != [[:space:]]* && "$value" != *[[:space:]] ]] || return 1
  ! LC_ALL=C grep -q '[[:cntrl:]|]' <<<"$value"
}
json_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  printf '%s' "$value"
}
uri_encode() {
  local value="$1" char encoded="" i hex LC_ALL=C
  for ((i=0; i<${#value}; i++)); do
    char="${value:i:1}"
    case "$char" in
      [A-Za-z0-9._~-]) encoded+="$char" ;;
      ' ') encoded+='%20' ;;
      *) printf -v hex '%%%02X' "'$char"; encoded+="$hex" ;;
    esac
  done
  printf '%s' "$encoded"
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
  WARP_GEOSITES="${WARP_GEOSITES:-}"
  CORE="sing-box"
  STATS_API_PORT="${STATS_API_PORT:-$DEFAULT_STATS_API_PORT}"
  BRUTAL_UP_MBPS="${BRUTAL_UP_MBPS:-$DEFAULT_BRUTAL_UP_MBPS}"
  BRUTAL_DOWN_MBPS="${BRUTAL_DOWN_MBPS:-$DEFAULT_BRUTAL_DOWN_MBPS}"
  MULTIPLEX_ENABLED="${MULTIPLEX_ENABLED:-1}"
  TCP_BRUTAL_ENABLED="${TCP_BRUTAL_ENABLED:-1}"
  OUTBOUND_IP_FAMILY="${OUTBOUND_IP_FAMILY:-auto}"
}

ensure_project_layout() {
  install -d -m 700 "$CONFIG_DIR" "$DATA_DIR" "$RULE_SET_DIR"
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

  if [[ -f "${CONFIG_DIR}/ags.env" && -f "${WORK_DIR}/argo-singbox.env" ]] &&
    ! cmp -s "${CONFIG_DIR}/ags.env" "${WORK_DIR}/argo-singbox.env"; then
    die "检测到两份内容不同的旧配置，拒绝自动合并。"
  fi
  verify_project_file_relocation "${CONFIG_DIR}/ags.env" "$ENV_FILE"
  verify_project_file_relocation "${WORK_DIR}/argo-singbox.env" "$ENV_FILE"
  verify_project_file_relocation "${WORK_DIR}/ags.env" "$ENV_FILE"
  verify_project_file_relocation "${WORK_DIR}/nodes.conf" "$NODES_CONFIG"
  verify_project_file_relocation "${WORK_DIR}/sing-box.json" "$SING_BOX_CONFIG"
  verify_project_file_relocation "${WORK_DIR}/nodes.txt" "$NODES_FILE"
  verify_project_file_relocation "${WORK_DIR}/subscription.txt" "$SUB_FILE"
  verify_project_file_relocation "${WORK_DIR}/subscription.base64" "$SUB_BASE64_FILE"
  verify_project_file_relocation "${WORK_DIR}/subscription.clash.yaml" "$SUB_CLASH_FILE"
  verify_project_file_relocation "${WORK_DIR}/subscription.sing-box.json" "$SUB_SING_BOX_FILE"
  verify_project_file_relocation "${WORK_DIR}/subscription.auto.svg" "$SUB_AUTO_QR_FILE"

  [[ -e "${CONFIG_DIR}/ags.env" || -e "${WORK_DIR}/argo-singbox.env" || -e "${WORK_DIR}/ags.env" || -e "${WORK_DIR}/nodes.conf" ||
    -e "${WORK_DIR}/sing-box.json" ||
    -e "${WORK_DIR}/nodes.txt" || -e "${WORK_DIR}/subscription.txt" ||
    -e "${WORK_DIR}/subscription.base64" || -e "${WORK_DIR}/subscription.clash.yaml" ||
    -e "${WORK_DIR}/subscription.sing-box.json" || -e "${WORK_DIR}/subscription.auto.svg" ]] || return 0

  ensure_project_layout
  relocate_project_file "${CONFIG_DIR}/ags.env" "$ENV_FILE" 600
  relocate_project_file "${WORK_DIR}/argo-singbox.env" "$ENV_FILE" 600
  relocate_project_file "${WORK_DIR}/ags.env" "$ENV_FILE" 600
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
    printf 'WARP_GEOSITES=%q\n' "$WARP_GEOSITES"
    printf 'STATS_API_PORT=%q\n' "$STATS_API_PORT"
    printf 'BRUTAL_UP_MBPS=%q\n' "$BRUTAL_UP_MBPS"
    printf 'BRUTAL_DOWN_MBPS=%q\n' "$BRUTAL_DOWN_MBPS"
    printf 'MULTIPLEX_ENABLED=%q\n' "$MULTIPLEX_ENABLED"
    printf 'TCP_BRUTAL_ENABLED=%q\n' "$TCP_BRUTAL_ENABLED"
    printf 'OUTBOUND_IP_FAMILY=%q\n' "$OUTBOUND_IP_FAMILY"
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
valid_ipv4() {
  local value="$1" part count=0 old_ifs="$IFS"
  IFS='.'
  for part in $value; do
    [[ "$part" =~ ^[0-9]+$ ]] && ((10#$part <= 255)) || { IFS="$old_ifs"; return 1; }
    ((count+=1))
  done
  IFS="$old_ifs"
  ((count == 4))
}
valid_endpoint_host() {
  local value="$1"
  if [[ "$value" == *:* ]]; then
    [[ "$value" =~ ^[0-9A-Fa-f:]+$ && "$value" == *:*:* ]]
  elif [[ "$value" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
    valid_ipv4 "$value"
  else
    valid_domain "$value"
  fi
}
config_import_key_allowed() {
  case "$1" in
    UUID|ARGO_DOMAIN|SERVER|SERVER_PORT|ARGO_TOKEN|ORIGIN_PORT|WARP_ENABLED|WARP_PROXY_PORT|WARP_DOMAINS|WARP_GEOSITES|STATS_API_PORT|BRUTAL_UP_MBPS|BRUTAL_DOWN_MBPS|MULTIPLEX_ENABLED|TCP_BRUTAL_ENABLED|OUTBOUND_IP_FAMILY) return 0 ;;
    *) return 1 ;;
  esac
}

load_config_file() {
  local file="$1" line key value line_number=0 server_value="" server_seen=0 server_port_seen=0
  [[ -f "$file" && ! -L "$file" && -r "$file" ]] || die "配置文件必须是可读的普通文件，且不能是符号链接：${file}"
  (( $(wc -c <"$file") <= 65536 )) || die "配置文件超过 64 KiB，拒绝导入。"
  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_number+=1))
    line="${line%$'\r'}"
    ((line_number == 1)) && line="${line#$'\xef\xbb\xbf'}"
    [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*([A-Z][A-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*)[[:space:]]*$ ]] ||
      die "配置文件第 ${line_number} 行格式无效，仅支持 KEY=value。"
    key="${BASH_REMATCH[1]}"; value="${BASH_REMATCH[2]}"
    value="${value%"${value##*[![:space:]]}"}"
    config_import_key_allowed "$key" || die "配置文件第 ${line_number} 行包含未知字段：${key}"
    if [[ "$value" == \'*\' && ${#value} -ge 2 ]]; then
      value="${value:1:${#value}-2}"
      [[ "$value" != *\'* ]] || die "配置文件第 ${line_number} 行的单引号值无效。"
    elif [[ "$value" == \"*\" && ${#value} -ge 2 ]]; then
      value="${value:1:${#value}-2}"
      [[ "$value" != *\"* ]] || die "配置文件第 ${line_number} 行的双引号值无效。"
    elif [[ "$value" =~ [[:space:]\#] ]]; then
      die "配置文件第 ${line_number} 行的未引用值不能包含空格或 #。"
    fi
    if [[ "$key" == "SERVER" ]]; then
      server_value="$value"; server_seen=1
    else
      printf -v "$key" '%s' "$value"
      [[ "$key" == "SERVER_PORT" ]] && server_port_seen=1
    fi
  done <"$file"
  if ((server_seen)); then
    if ((server_port_seen)); then
      [[ "$server_value" != *:* ]] || die "配置文件不能同时使用 SERVER=主机:端口 与 SERVER_PORT。"
      valid_endpoint_host "$server_value" || die "配置文件中的 SERVER 无效。"
      SERVER="$server_value"
    else
      parse_endpoint "$server_value"
    fi
  fi
  green "已读取配置文件：${file}"
}
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

tcp_brutal_debian_system() {
  local os_id=""
  [[ -r /etc/os-release ]] || return 1
  os_id="$(
    # shellcheck disable=SC1091
    source /etc/os-release
    printf '%s' "${ID:-}"
  )"
  [[ "$os_id" == "debian" ]]
}

tcp_brutal_debian_meta_packages() {
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || true)"
  case "$arch" in
    amd64|arm64) printf 'linux-image-%s linux-headers-%s' "$arch" "$arch" ;;
    *) return 1 ;;
  esac
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
  TCP_BRUTAL_REMEDIATION=""
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
    TCP_BRUTAL_SUPPORT_ERROR="Argo-Singbox 仅支持通过 Debian/Ubuntu APT 安装 TCP Brutal 官方依赖。"
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
      TCP_BRUTAL_SUPPORT_ERROR="当前运行内核 ${release} 缺少匹配头文件，且 APT 中没有可安装的 ${headers_package}；不能使用其他版本头文件替代。"
      if tcp_brutal_debian_system && tcp_brutal_debian_meta_packages >/dev/null; then
        TCP_BRUTAL_REMEDIATION="debian-kernel-upgrade"
      fi
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

guide_tcp_brutal_debian_kernel() {
  local apt_refreshed="${1:-0}" answer meta_packages_text
  local -a meta_packages
  meta_packages_text="$(tcp_brutal_debian_meta_packages)" ||
    die "当前 Debian 架构没有受支持的内核元包升级引导。"
  read -r -a meta_packages <<<"$meta_packages_text"
  section "内核升级引导"
  menu_hint "将安装 Debian 发行版新内核及其匹配头文件。"
  key_value "内核软件包" "$meta_packages_text"
  menu_hint "当前内核不会立即切换，现有服务会继续运行。"
  menu_hint "本次不会继续安装 TCP Brutal。"
  menu_hint "必须重启进入新内核，再运行 ${COMMAND_NAME} -c。"
  menu_hint "内核安装需要额外磁盘空间，请确保 /boot 与根分区空间充足。"
  read_input "同意安装 Debian 新内核与匹配头文件？[y/N]：" answer
  is_exit_input "$answer" && { yellow "已取消内核升级 · 未安装新内核"; return 0; }
  [[ "$answer" =~ ^[Yy]$ ]] || { yellow "已取消内核升级 · 未安装新内核"; return 0; }

  if [[ "$apt_refreshed" != "1" ]]; then
    info "正在刷新 APT 软件包索引..."
    apt-get update || die "APT 软件包索引更新失败，未安装新内核。"
  fi
  info "正在安装 Debian 新内核与匹配头文件..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${meta_packages[@]}" ||
    die "Debian 新内核或匹配头文件安装失败。"
  green "Debian 新内核与匹配头文件已安装。"
  section "重启确认"
  menu_hint "重启会立即中断 SSH 和当前业务连接，请先保存其他任务。"
  menu_hint "重启后系统才会使用新内核。"
  menu_hint "连接恢复后，请重新运行 ${COMMAND_NAME} -c 安装 TCP Brutal。"
  read_input "立即重启服务器？[y/N]：" answer
  is_exit_input "$answer" && { yellow "已保留当前内核运行；请稍后手动重启。"; return 0; }
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    info "正在重启服务器，SSH 连接即将断开..."
    sync
    systemctl reboot || die "服务器重启请求失败，请手动执行 reboot。"
    return 0
  fi
  yellow "新内核尚未启用；请稍后重启，再安装 TCP Brutal。"
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
  if [[ "$TCP_BRUTAL_ENABLED" != "1" ]]; then
    ui_printf '未启用 · 模块%s' "$([[ "$IS_BRUTAL" == "true" ]] && ui_printf '已加载' || ui_printf '未加载')"
  elif [[ "$MULTIPLEX_ENABLED" != "1" ]]; then
    ui_printf '未启用 · h2mux 未启用'
  elif [[ "$IS_BRUTAL" == "true" ]]; then
    ui_printf '已启用 · %s/%s Mbps' "$BRUTAL_UP_MBPS" "$BRUTAL_DOWN_MBPS"
  else
    ui_printf '不可用 · 缺少 brutal 内核模块'
  fi
}

multiplex_status() {
  if [[ "$MULTIPLEX_ENABLED" == "1" ]]; then
    ui_printf '已启用 · %s streams · padding' "$MULTIPLEX_MAX_STREAMS"
  else
    ui_printf '未启用'
  fi
}

tcp_brutal_config_value() {
  if [[ "$TCP_BRUTAL_ENABLED" == "1" && "$MULTIPLEX_ENABLED" == "1" && "$IS_BRUTAL" == "true" ]]; then
    printf true
  else
    printf false
  fi
}

validate_environment() {
  valid_core "$CORE" || die "核心类型无效。"
  valid_uuid "$UUID" || die "UUID 格式不正确。"
  valid_argo_token "$ARGO_TOKEN" || die "Argo Token 格式不正确。"
  valid_domain "$ARGO_DOMAIN" || die "Argo 域名格式不正确。"
  valid_endpoint_host "$SERVER" || die "优选入口格式不正确。"
  valid_port "$SERVER_PORT" || die "优选入口端口无效。"
  valid_port "$ORIGIN_PORT" || die "Argo 回源端口无效。"
  valid_port "$STATS_API_PORT" || die "流量统计 API 端口无效。"
  valid_bandwidth_mbps "$BRUTAL_UP_MBPS" || die "TCP Brutal 上传带宽无效。"
  valid_bandwidth_mbps "$BRUTAL_DOWN_MBPS" || die "TCP Brutal 下载带宽无效。"
  [[ "$MULTIPLEX_ENABLED" =~ ^[01]$ ]] || die "Multiplex 启停配置无效。"
  [[ "$TCP_BRUTAL_ENABLED" =~ ^[01]$ ]] || die "TCP Brutal 启停配置无效。"
  [[ "$OUTBOUND_IP_FAMILY" =~ ^(auto|ipv4|ipv6)$ ]] || die "节点落地 IP 配置无效。"
  ((10#$STATS_API_PORT != 10#$ORIGIN_PORT)) || die "流量统计 API 端口不能与 Argo 回源端口相同。"
  if [[ "$WARP_ENABLED" == "1" ]]; then
    valid_port "$WARP_PROXY_PORT" || die "WARP 本地代理端口无效。"
    ((10#$WARP_PROXY_PORT != 10#$STATS_API_PORT)) || die "WARP 代理端口不能与流量统计 API 端口相同。"
    ((10#$WARP_PROXY_PORT != 10#$ORIGIN_PORT)) || die "WARP 代理端口不能与 Argo 回源端口相同。"
    if [[ -s "$NODES_CONFIG" ]] &&
      awk -F'|' -v port="$WARP_PROXY_PORT" '$4 == port {found=1} END {exit !found}' "$NODES_CONFIG"; then
      die "WARP 代理端口不能与节点监听端口相同：${WARP_PROXY_PORT}"
    fi
    WARP_DOMAINS="$(normalize_warp_domains "$WARP_DOMAINS")"
    WARP_GEOSITES="$(normalize_warp_geosites "$WARP_GEOSITES")"
    [[ -n "$WARP_DOMAINS$WARP_GEOSITES" ]] || die "WARP 至少需要一个域名或 geosite 分类。"
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
  printf '%s\n' "$output"
}

normalize_warp_geosites() {
  local input="$1" item category output="" seen="," old_ifs="$IFS"
  IFS=','
  for item in $input; do
    item="${item//[[:space:]]/}"
    [[ -n "$item" ]] || continue
    category="${item,,}"
    category="${category#geosite:}"
    category="${category#geosite-}"
    [[ "$category" =~ ^[a-z0-9][a-z0-9_!@.-]*$ ]] ||
      die "WARP geosite 分类无效：${item}"
    [[ "$seen" == *",${category},"* ]] && continue
    output+="${output:+,}${category}"
    seen+="${category},"
  done
  IFS="$old_ifs"
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

warp_geosite_tags_json() {
  local category first=1 old_ifs="$IFS"
  IFS=','
  for category in $WARP_GEOSITES; do
    [[ -n "$category" ]] || continue
    ((first)) || printf ','
    first=0
    printf '"geosite-%s"' "$category"
  done
  IFS="$old_ifs"
}

# Fifth field accepts URLs; legacy host:port:user:pass remains readable.
parse_node_proxy() {
  local value="$1" type=socks host port username password extra authority credentials
  if [[ "$value" == *://* ]]; then
    case "$value" in
      socks5://*) type=socks; authority="${value#socks5://}" ;;
      http://*) type=http; authority="${value#http://}" ;;
      *) return 1 ;;
    esac
    [[ "$authority" == *@* && "$authority" != *[/$'\n'$'\r''|']* ]] || return 1
    credentials="${authority%@*}"; authority="${authority##*@}"
    [[ "$credentials" == *:* ]] || return 1
    username="${credentials%%:*}"; password="${credentials#*:}"
    if [[ "$authority" == \[* ]]; then
      [[ "$authority" =~ ^\[([0-9A-Fa-f:]+)\]:([0-9]+)$ ]] || return 1
      host="${BASH_REMATCH[1]}"; port="${BASH_REMATCH[2]}"
    else
      [[ "$authority" == *:* ]] || return 1
      host="${authority%:*}"; port="${authority##*:}"
    fi
  else
    IFS=':' read -r host port username password extra <<<"$value"
    [[ -z "${extra:-}" ]] || return 1
  fi
  valid_endpoint_host "$host" && valid_port "$port" || return 1
  [[ "$username" =~ ^[A-Za-z0-9._~-]+$ && "$password" =~ ^[A-Za-z0-9._~-]+$ ]] || return 1
  printf '%s|%s|%s|%s|%s\n' "$type" "$host" "$((10#$port))" "$username" "$password"
}
parse_socks5() {
  local values type host port username password
  values="$(parse_node_proxy "$1")" || die "节点代理格式无效 · 使用 http://user:pass@host:port 或 socks5://user:pass@host:port"
  IFS='|' read -r type host port username password <<<"$values"
  printf '%s|%s|%s|%s\n' "$host" "$port" "$username" "$password"
}
valid_socks5() { parse_node_proxy "$1" >/dev/null; }
node_outbound_value() {
  local values type host port username password
  case "$1" in direct:ipv4) printf 'IPv4 · direct'; return ;; direct:ipv6) printf 'IPv6 · direct'; return ;; esac
  [[ -n "$1" ]] || { printf 'direct'; return; }
  values="$(parse_node_proxy "$1")" || return 1
  IFS='|' read -r type host port username password <<<"$values"
  [[ "$type" == socks ]] && type=SOCKS5 || type=HTTP
  [[ "$host" != *:* ]] || host="[$host]"
  printf '%s · %s:%s' "$type" "$host" "$port"
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
  local highest="$ORIGIN_PORT" port candidate
  while IFS='|' read -r _ _ _ port _; do
    valid_port "$port" && ((10#$port > 10#$highest)) && highest="$port"
  done <"$NODES_CONFIG"
  candidate="$((10#$highest + 1))"
  while ((candidate <= 65535)); do
    if ((candidate != 10#$STATS_API_PORT && candidate != 10#$ORIGIN_PORT)) &&
      [[ "$WARP_ENABLED" != "1" || candidate -ne 10#$WARP_PROXY_PORT ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
    ((candidate+=1))
  done
  die "没有可用的后续节点端口。"
}

validate_nodes_config() {
  local tag protocol path port socks extra seen_tags="|" seen_paths="|" seen_ports="|"
  [[ -s "$NODES_CONFIG" ]] || die "节点配置为空：${NODES_CONFIG}"
  while IFS='|' read -r tag protocol path port socks extra; do
    [[ -n "$tag" && -z "${extra:-}" ]] || die "节点配置字段数量错误。"
    valid_node_tag "$tag" || die "节点标签无效：${tag}"
    case "$protocol" in
      vless|vmess|trojan) ;;
      *) die "不支持的节点协议：${protocol}" ;;
    esac
    valid_path "$path" || die "传输路径格式错误：${path}"
    valid_port "$port" || die "节点端口错误：${port}"
    ((10#$port != 10#$ORIGIN_PORT)) || die "节点端口与 Argo 回源端口冲突：${port}"
    ((10#$port != 10#$STATS_API_PORT)) || die "节点端口与流量统计 API 端口冲突：${port}"
    [[ "$WARP_ENABLED" != "1" || 10#$port -ne 10#$WARP_PROXY_PORT ]] ||
      die "节点端口与 WARP 代理端口冲突：${port}"
    [[ "$seen_tags" != *"|${tag}|"* && "$seen_paths" != *"|${path}|"* &&
      "$seen_ports" != *"|${port}|"* ]] || die "节点标签、路径或端口重复。"
    seen_tags+="${tag}|"; seen_paths+="${path}|"; seen_ports+="${port}|"
    is_direct_outbound "$socks" || parse_socks5 "$socks" >/dev/null
  done <"$NODES_CONFIG"
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) die "仅支持 amd64 和 arm64 架构。" ;;
  esac
}

try_download() {
  local url="$1" output="$2"
  local candidate
  for candidate in "$url" \
    "https://github-proxy.fiatnorm.pp.ua/${url}" \
    "https://ghproxy.net/${url}" \
    "https://github.moeyy.xyz/${url}"; do
    if curl -fsSL --retry 3 --retry-all-errors --connect-timeout 10 --max-time 180 \
      "$candidate" -o "${output}.part"; then
      if [[ -s "${output}.part" ]]; then
        mv -f "${output}.part" "$output"
        return 0
      fi
    fi
    rm -f "${output}.part"
  done
  return 1
}

download() {
  local url="$1" output="$2"
  try_download "$url" "$output" ||
    die "下载失败（已尝试直连和 GitHub 反代）：${url}"
}

ensure_warp_geosite_files() {
  local category target url stage old_ifs="$IFS"
  [[ "$WARP_ENABLED" == "1" && -n "$WARP_GEOSITES" ]] || return 0
  install -d -m 700 "$RULE_SET_DIR"
  IFS=','
  for category in $WARP_GEOSITES; do
    target="${RULE_SET_DIR}/geosite-${category}.srs"
    [[ -s "$target" ]] && continue
    stage="$(mktemp "${RULE_SET_DIR}/.geosite-${category}.XXXXXX")"
    url="https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-${category}.srs"
    if ! try_download "$url" "$stage"; then
      rm -f "$stage"
      IFS="$old_ifs"
      die "无法获取 geosite-${category} 规则集，旧配置未改动。"
    fi
    install -m 600 "$stage" "$target"
    rm -f "$stage"
  done
  IFS="$old_ifs"
}

fetch_latest_installer() {
  local target="$1" checksum expected attempt
  checksum="$(mktemp)"
  for attempt in {1..3}; do
    download "https://raw.githubusercontent.com/${PROJECT_REPO}/${PROJECT_BRANCH}/${CHECKSUM_NAME}" "$checksum"
    download "https://raw.githubusercontent.com/${PROJECT_REPO}/${PROJECT_BRANCH}/${SCRIPT_NAME}" "$target"
    expected="$(awk -v script="$SCRIPT_NAME" '$2 == script || $2 == "*" script {print $1; exit}' "$checksum")"
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
  local mode="${1:-prompt}" answer codename key_file fingerprint
  command -v warp-cli >/dev/null 2>&1 && return
  if [[ "$mode" != "auto" ]]; then
    read_input "确认安装 Cloudflare WARP 客户端？[y/N]：" answer
    is_exit_input "$answer" && die "已取消安装 Cloudflare WARP 客户端。"
    is_confirmed "$answer" || die "已取消安装 Cloudflare WARP 客户端。"
  fi
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

configure_warp_proxy() {
  local mode="${1:-prompt}"
  [[ "$WARP_ENABLED" == "1" ]] || return 0
  install_cloudflare_warp "$mode"
  systemctl enable --now warp-svc >/dev/null 2>&1 || die "无法启动 warp-svc。"
  ensure_warp_registration
  warp-cli --accept-tos mode proxy >/dev/null &&
    warp-cli --accept-tos proxy port "$WARP_PROXY_PORT" >/dev/null &&
    warp-cli --accept-tos connect >/dev/null ||
    die "无法把 WARP 客户端切换到本地代理模式。"
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
    read_input "确认删除并重新注册旧 WARP 注册？[y/N]：" answer
    is_exit_input "$answer" && die "已取消 WARP 重新注册。"
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
  local tag protocol path port socks first=1 values host proxy_port username password brutal_value multiplex_json category outbound_family direct_fields proxy_type
  SING_BOX_CONFIG="$config_target"
  ensure_project_layout
  ensure_nodes_config
  validate_environment
  validate_nodes_config
  ensure_warp_geosite_files
  detect_tcp_brutal
  outbound_family="$(effective_outbound_ip_family)" ||
    die "无法通过 GeoJS 确认 IPv4 或 IPv6 公网出口，未生成 Sing-box 配置。"
  case "$outbound_family" in
    ipv4) direct_fields=',"inet4_bind_address":"0.0.0.0","domain_resolver":{"server":"local","strategy":"ipv4_only"}' ;;
    ipv6) direct_fields=',"inet6_bind_address":"::","domain_resolver":{"server":"local","strategy":"ipv6_only"}' ;;
    *) die "节点落地 IP 配置无效。" ;;
  esac
  brutal_value="$(tcp_brutal_config_value)"
  if [[ "$MULTIPLEX_ENABLED" == "1" ]]; then
    multiplex_json="\"multiplex\":{\"enabled\":true,\"padding\":true,\"brutal\":{\"enabled\":${brutal_value},\"up_mbps\":${BRUTAL_UP_MBPS},\"down_mbps\":${BRUTAL_DOWN_MBPS}}}"
  else
    multiplex_json='"multiplex":{"enabled":false}'
  fi
  printf '{"log":{"level":"info","timestamp":true},"dns":{"servers":[{"type":"local","tag":"local"}]},"inbounds":[\n' >"$SING_BOX_CONFIG"
  while IFS='|' read -r tag protocol path port socks; do
    ((first)) || printf ',\n' >>"$SING_BOX_CONFIG"; first=0
    printf '{"type":"%s","tag":"%s","listen":"127.0.0.1","listen_port":%s,' "$protocol" "$tag" "$port" >>"$SING_BOX_CONFIG"
    case "$protocol" in
      trojan) printf '"users":[{"password":"%s"}],' "$UUID" >>"$SING_BOX_CONFIG" ;;
      vmess) printf '"users":[{"uuid":"%s","alterId":0}],' "$UUID" >>"$SING_BOX_CONFIG" ;;
      vless) printf '"users":[{"uuid":"%s","flow":""}],' "$UUID" >>"$SING_BOX_CONFIG" ;;
    esac
    printf '"transport":{"type":"ws","path":"%s","max_early_data":2560,"early_data_header_name":"Sec-WebSocket-Protocol"},' "$path" >>"$SING_BOX_CONFIG"
    printf '%s}' "$multiplex_json" >>"$SING_BOX_CONFIG"
  done <"$NODES_CONFIG"
  printf '\n],"outbounds":[{"type":"direct","tag":"direct"%s}' "$direct_fields" >>"$SING_BOX_CONFIG"
  if [[ "$WARP_ENABLED" == "1" ]]; then
    valid_port "$WARP_PROXY_PORT" || die "WARP 本地代理端口无效。"
    WARP_DOMAINS="$(normalize_warp_domains "$WARP_DOMAINS")"
    WARP_GEOSITES="$(normalize_warp_geosites "$WARP_GEOSITES")"
    printf ',{"type":"socks","tag":"warp","server":"127.0.0.1","server_port":%s,"version":"5"}' \
      "$WARP_PROXY_PORT" >>"$SING_BOX_CONFIG"
  fi
  while IFS='|' read -r tag protocol path port socks; do
    [[ -n "$socks" ]] || continue
    if is_direct_outbound "$socks"; then
      case "$socks" in direct:ipv4) proxy_type=prefer_ipv4 ;; direct:ipv6) proxy_type=prefer_ipv6 ;; esac
      printf ',{"type":"direct","tag":"direct-%s","domain_resolver":{"server":"local","strategy":"%s"}}' "$tag" "$proxy_type" >>"$SING_BOX_CONFIG"
      continue
    fi
    values="$(parse_node_proxy "$socks")"; IFS='|' read -r proxy_type host proxy_port username password <<<"$values"
    printf ',{"type":"%s","tag":"socks-%s","server":"%s","server_port":%s,"username":"%s","password":"%s"' \
      "$proxy_type" "$tag" "$host" "$proxy_port" "$username" "$password" >>"$SING_BOX_CONFIG"
    [[ "$proxy_type" != socks ]] || printf ',"version":"5"' >>"$SING_BOX_CONFIG"
    printf '}' >>"$SING_BOX_CONFIG"
  done <"$NODES_CONFIG"
  printf '],"experimental":{"clash_api":{"external_controller":"127.0.0.1:%s"}},"route":{"default_domain_resolver":"local","rules":[' \
    "$STATS_API_PORT" >>"$SING_BOX_CONFIG"; first=1
  if [[ "$WARP_ENABLED" == "1" ]]; then
    printf '{"action":"sniff"}' >>"$SING_BOX_CONFIG"
    first=0
    if [[ -n "$WARP_DOMAINS" ]]; then
      printf ',{"domain_suffix":[' >>"$SING_BOX_CONFIG"
      warp_domains_json >>"$SING_BOX_CONFIG"
      printf '],"action":"route","outbound":"warp"}' >>"$SING_BOX_CONFIG"
    fi
    if [[ -n "$WARP_GEOSITES" ]]; then
      printf ',{"rule_set":[' >>"$SING_BOX_CONFIG"
      warp_geosite_tags_json >>"$SING_BOX_CONFIG"
      printf '],"action":"route","outbound":"warp"}' >>"$SING_BOX_CONFIG"
    fi
  fi
  while IFS='|' read -r tag protocol path port socks; do
    [[ -n "$socks" ]] || continue
    ((first)) || printf ',' >>"$SING_BOX_CONFIG"; first=0
    if is_direct_outbound "$socks"; then proxy_type=direct; else proxy_type=socks; fi
    printf '{"inbound":["%s"],"action":"route","outbound":"%s-%s"}' "$tag" "$proxy_type" "$tag" >>"$SING_BOX_CONFIG"
  done <"$NODES_CONFIG"
  printf ']' >>"$SING_BOX_CONFIG"
  if [[ -n "$WARP_GEOSITES" ]]; then
    printf ',"rule_set":[' >>"$SING_BOX_CONFIG"; first=1
    while IFS= read -r category; do
      [[ -n "$category" ]] || continue
      ((first)) || printf ',' >>"$SING_BOX_CONFIG"; first=0
      printf '{"type":"local","tag":"geosite-%s","format":"binary","path":"%s/geosite-%s.srs"}' \
        "$category" "$RULE_SET_DIR" "$category" >>"$SING_BOX_CONFIG"
    done < <(tr ',' '\n' <<<"$WARP_GEOSITES")
    printf ']' >>"$SING_BOX_CONFIG"
  fi
  printf ',"final":"direct"}}\n' >>"$SING_BOX_CONFIG"
  chmod 600 "$SING_BOX_CONFIG"
  sing_box_check "$check_binary" "$SING_BOX_CONFIG"
)


write_all_core_configs() {
  [[ -x "${BIN_DIR}/sing-box" ]] || die "Sing-box 核心不存在。"
  write_sing_box_config
}

write_available_core_configs() { write_all_core_configs; }

subscription_index_rows() {
  local route file modified size format filename download
  while IFS='|' read -r route file format filename; do
    modified="$(LC_ALL=C date -r "$file" '+%d %b %Y %H:%M:%S')"
    size="$(stat -c %s "$file")B"
    if [[ "$route" == auto ]]; then
      format='<span data-adaptive="adaptive"></span>'
      size='<span data-adaptive="client"></span>'
    fi
    download="${route}.txt"
    case "$route" in clash) download=clash.yaml ;; sing-box) download=sing-box.json ;; esac
    printf '<div class="row"><div class="file-cell"><span class="file"><svg class="material-icon" xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#e3e3e3" aria-hidden="true"><path d="M280-80q-33 0-56.5-23.5T200-160v-640q0-33 23.5-56.5T280-880h247q16 0 30.5 6t25.5 17l154 154q11 11 17 25.5t6 30.5v487q0 33-23.5 56.5T680-80H280Zm160-720H280v640h400v-400H560q-50 0-85-35t-35-85v-120Zm80 0v120q0 17 11.5 28.5T560-640h120v-7L527-800h-7ZM400-200q-17 0-28.5-11.5T360-240q0-17 11.5-28.5T400-280h80q17 0 28.5 11.5T520-240q0 17-11.5 28.5T480-200h-80Zm0-160q-17 0-28.5-11.5T360-400q0-17 11.5-28.5T400-440h160q17 0 28.5 11.5T600-400q0 17-11.5 28.5T560-360H400Z"/></svg>%s</span><a class="file-open" href="%s" data-file="%s"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="M15 4h5v5M20 4L10 14M18 13v7H4V6h7"/></svg></a></div><span class="format">%s</span><time class="date">%s</time><span class="size">%s</span><a class="download file-download" data-file="%s" href="%s" download="%s"><svg viewBox="0 0 24 24"><path d="M12 3v12m-5-5 5 5 5-5M5 17v4h14v-4"/></svg><span class="download-label" data-i18n="download"></span></a></div>' \
      "$filename" "$route" "$filename" "$format" "$modified" "$size" "$filename" "$route" "$download"
  done <<EOF
raw|${SUB_FILE}|URI|raw
auto|${SUB_BASE64_FILE}|Adaptive|auto
base64|${SUB_BASE64_FILE}|Base64|base64
clash|${SUB_CLASH_FILE}|YAML|clash
sing-box|${SUB_SING_BOX_FILE}|JSON|sing-box
EOF
}

write_subscription_panel() (
  local panel_temp icon_temp stage template html language selected="$UI_LANGUAGE" title
  stage="$(mktemp -d "${SUBSCRIPTION_DIR}/.panel.XXXXXX")"
  panel_temp="$stage/index.html"; icon_temp="$stage/favicon.svg"
  trap 'rm -rf "$stage"' EXIT
  # assets/subscription-panel.html is embedded for standalone installs.
  template="$(base64 -d <<'HTML'
PCFkb2N0eXBlIGh0bWw+CjxodG1sIGxhbmc9IkBMQU5HQCI+PGhlYWQ+PG1ldGEgY2hhcnNldD0i
dXRmLTgiPjxtZXRhIG5hbWU9InZpZXdwb3J0IiBjb250ZW50PSJ3aWR0aD1kZXZpY2Utd2lkdGgs
aW5pdGlhbC1zY2FsZT0xIj48bWV0YSBuYW1lPSJjb2xvci1zY2hlbWUiIGNvbnRlbnQ9ImxpZ2h0
Ij48YmFzZSBocmVmPSIvQFVVSURALyI+PHRpdGxlPkBUSVRMRUA8L3RpdGxlPjxsaW5rIHJlbD0i
aWNvbiIgdHlwZT0iaW1hZ2Uvc3ZnK3htbCIgaHJlZj0iZmF2aWNvbi5zdmciPjxzdHlsZT4KOnJv
b3R7Y29sb3Itc2NoZW1lOmxpZ2h0O2ZvbnQtZmFtaWx5OiJSb2JvdG8gRmxleCIsUm9ib3RvLCJO
b3RvIFNhbnMgU0MiLCJNaWNyb3NvZnQgWWFIZWkiLHNhbnMtc2VyaWY7LS1zdXJmYWNlOiNmZWZi
ZmY7LS1sb3c6I2Y4ZjFmNjstLWhpZ2g6I2YyZWNlZTstLWluazojMWMxYjFkOy0tbXV0ZWQ6IzRk
NDI1NjstLW91dGxpbmU6I2U4ZTBlODstLXByaW1hcnk6IzY0NDJkNjstLWNvbnRhaW5lcjojZThk
ZWY4fQoqe2JveC1zaXppbmc6Ym9yZGVyLWJveH1ib2R5e21hcmdpbjowO2hlaWdodDoxMDBkdmg7
YmFja2dyb3VuZDp2YXIoLS1zdXJmYWNlKTtjb2xvcjp2YXIoLS1pbmspO2ZvbnQtc2l6ZToxNHB4
O2xpbmUtaGVpZ2h0OjEuNTtvdmVyZmxvdzpoaWRkZW59YXtjb2xvcjppbmhlcml0O3RleHQtZGVj
b3JhdGlvbjpub25lfWJ1dHRvbntmb250OmluaGVyaXQ7Y3Vyc29yOnBvaW50ZXJ9YTpmb2N1cy12
aXNpYmxlLGJ1dHRvbjpmb2N1cy12aXNpYmxle291dGxpbmU6M3B4IHNvbGlkIHZhcigtLXByaW1h
cnkpO291dGxpbmUtb2Zmc2V0OjJweH1baGlkZGVuXXtkaXNwbGF5Om5vbmUhaW1wb3J0YW50fS50
b3BiYXJ7aGVpZ2h0OjY0cHg7ZGlzcGxheTpmbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5
LWNvbnRlbnQ6c3BhY2UtYmV0d2VlbjtwYWRkaW5nOjAgMjRweDtiYWNrZ3JvdW5kOnZhcigtLWxv
dyk7Ym9yZGVyLWJvdHRvbToxcHggc29saWQgdmFyKC0tb3V0bGluZSl9LmJyYW5ke2Rpc3BsYXk6
ZmxleDtnYXA6MTJweDthbGlnbi1pdGVtczpjZW50ZXI7Zm9udC1zaXplOjIycHg7Zm9udC13ZWln
aHQ6NzAwfS5icmFuZCBpbWd7d2lkdGg6NDBweDtoZWlnaHQ6NDBweH0uY2hpcHtwYWRkaW5nOjhw
eCAxNnB4O2JvcmRlci1yYWRpdXM6OTk5cHg7YmFja2dyb3VuZDp2YXIoLS1jb250YWluZXIpO2Nv
bG9yOiMzNDAwOTg7Zm9udC1zaXplOjEzcHg7Zm9udC13ZWlnaHQ6NzUwfS5yYWlse3Bvc2l0aW9u
OmZpeGVkO2luc2V0OjY0cHggYXV0byAwIDA7d2lkdGg6ODhweDtwYWRkaW5nOjEycHggOHB4O2Jh
Y2tncm91bmQ6dmFyKC0tbG93KTtib3JkZXItcmlnaHQ6MXB4IHNvbGlkIHZhcigtLW91dGxpbmUp
O2Rpc3BsYXk6ZmxleDtmbGV4LWRpcmVjdGlvbjpjb2x1bW47Z2FwOjhweH0ubmF2LWl0ZW17ZGlz
cGxheTpmbGV4O2ZsZXgtZGlyZWN0aW9uOmNvbHVtbjthbGlnbi1pdGVtczpjZW50ZXI7anVzdGlm
eS1jb250ZW50OmNlbnRlcjtnYXA6NHB4O21pbi1oZWlnaHQ6NjRweDtib3JkZXItcmFkaXVzOjIy
cHg7Y29sb3I6dmFyKC0tbXV0ZWQpO2ZvbnQtc2l6ZToxMXB4O2ZvbnQtd2VpZ2h0OjcwMH0ubmF2
LWl0ZW0uYWN0aXZle2JhY2tncm91bmQ6dmFyKC0tY29udGFpbmVyKTtjb2xvcjojMzQwMDk4fS5u
YXYtaXRlbTpob3ZlcntiYWNrZ3JvdW5kOnZhcigtLWhpZ2gpfS5uYXYtaXRlbS5saWNlbnNle21h
cmdpbi10b3A6YXV0b31zdmd7d2lkdGg6MjJweDtoZWlnaHQ6MjJweDtmaWxsOm5vbmU7c3Ryb2tl
OmN1cnJlbnRDb2xvcjtzdHJva2Utd2lkdGg6MS44O3N0cm9rZS1saW5lY2FwOnJvdW5kO3N0cm9r
ZS1saW5lam9pbjpyb3VuZH0uc2hlbGx7bWFyZ2luLWxlZnQ6ODhweDtoZWlnaHQ6Y2FsYygxMDBk
dmggLSA2NHB4KTtwYWRkaW5nOjI0cHg7ZGlzcGxheTpncmlkO3BsYWNlLWl0ZW1zOmNlbnRlcn1t
YWlue3dpZHRoOm1pbigxMjAwcHgsMTAwJSk7aGVpZ2h0OjEwMCU7bWluLWhlaWdodDowO2Rpc3Bs
YXk6ZmxleDtmbGV4LWRpcmVjdGlvbjpjb2x1bW47anVzdGlmeS1jb250ZW50OmNlbnRlcjtnYXA6
MTZweH0udmlld3ttaW4taGVpZ2h0OjB9LnBhZ2UtaGVhZGVye2Rpc3BsYXk6ZmxleDtqdXN0aWZ5
LWNvbnRlbnQ6c3BhY2UtYmV0d2VlbjthbGlnbi1pdGVtczplbmQ7Z2FwOjE2cHg7bWFyZ2luLWJv
dHRvbToxNnB4fS5leWVicm93e21hcmdpbjowIDAgNnB4O2NvbG9yOnZhcigtLXByaW1hcnkpO2Zv
bnQtc2l6ZToxMnB4O2ZvbnQtd2VpZ2h0OjgwMDtsZXR0ZXItc3BhY2luZzouMTJlbX1oMXttYXJn
aW46MDtmb250LXNpemU6Y2xhbXAoMzBweCw0dncsNDRweCk7Zm9udC13ZWlnaHQ6NTIwO2xpbmUt
aGVpZ2h0OjEuMTtsZXR0ZXItc3BhY2luZzotLjAzNWVtfWgye2ZvbnQtc2l6ZToyMHB4O2ZvbnQt
d2VpZ2h0OjYwMDttYXJnaW46MCAwIDhweH1we21hcmdpbjowfS5oZXJve2Rpc3BsYXk6ZmxleDtq
dXN0aWZ5LWNvbnRlbnQ6c3BhY2UtYmV0d2VlbjthbGlnbi1pdGVtczpjZW50ZXI7Z2FwOjIwcHg7
cGFkZGluZzoyMHB4IDI0cHg7bWFyZ2luLWJvdHRvbToyMHB4O2JvcmRlci1yYWRpdXM6MjRweDti
YWNrZ3JvdW5kOnZhcigtLWNvbnRhaW5lcil9Lmhlcm8gcHtjb2xvcjp2YXIoLS1tdXRlZCk7bWF4
LXdpZHRoOjYwMHB4O2ZvbnQtc2l6ZToxNHB4O21hcmdpbi1ib3R0b206MTJweH0uYnV0dG9uLC5k
b3dubG9hZHtkaXNwbGF5OmlubGluZS1mbGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNv
bnRlbnQ6Y2VudGVyO2dhcDo3cHg7bWluLWhlaWdodDo0NHB4O3BhZGRpbmc6MCAxNnB4O2JvcmRl
cjowO2JvcmRlci1yYWRpdXM6OTk5cHg7YmFja2dyb3VuZDp2YXIoLS1wcmltYXJ5KTtjb2xvcjoj
ZmZmO2ZvbnQtc2l6ZToxMnB4O2ZvbnQtd2VpZ2h0Ojc2MH0uZG93bmxvYWR7YmFja2dyb3VuZDp2
YXIoLS1jb250YWluZXIpO2NvbG9yOiMzNDAwOTg7bWluLXdpZHRoOjQ0cHh9LnFye2ZsZXg6bm9u
ZTt3aWR0aDoxNDhweDtoZWlnaHQ6MTQ4cHg7YmFja2dyb3VuZDp3aGl0ZTtib3JkZXItcmFkaXVz
OjE0cHg7cGFkZGluZzo4cHh9LnFyIGltZ3t3aWR0aDoxMDAlO2hlaWdodDoxMDAlfS5maWxlc3tv
dmVyZmxvdzpoaWRkZW47Ym9yZGVyOjFweCBzb2xpZCB2YXIoLS1vdXRsaW5lKTtib3JkZXItcmFk
aXVzOjI0cHg7YmFja2dyb3VuZDp2YXIoLS1sb3cpfS5yb3d7ZGlzcGxheTpncmlkO2dyaWQtdGVt
cGxhdGUtY29sdW1uczpyZXBlYXQoNSxtaW5tYXgoMCwxZnIpKTthbGlnbi1pdGVtczpjZW50ZXI7
Z2FwOjEycHg7cGFkZGluZzowIDE2cHg7bWluLWhlaWdodDo2NnB4fS5yb3crLnJvd3tib3JkZXIt
dG9wOjFweCBzb2xpZCB2YXIoLS1vdXRsaW5lKX0uaGVhZHttaW4taGVpZ2h0OjQwcHg7YmFja2dy
b3VuZDp2YXIoLS1oaWdoKTtjb2xvcjp2YXIoLS1wcmltYXJ5KTtmb250LXNpemU6MTFweDtmb250
LXdlaWdodDo4MDB9LnJvdz4qe3RleHQtYWxpZ246Y2VudGVyO2p1c3RpZnktc2VsZjpjZW50ZXJ9
LmZpbGUtY2VsbHtkaXNwbGF5OmZsZXg7YWxpZ24taXRlbXM6Y2VudGVyO2p1c3RpZnktY29udGVu
dDpjZW50ZXI7Z2FwOjEwcHg7bWluLXdpZHRoOjB9LmZpbGUtb3BlbntkaXNwbGF5OmlubGluZS1m
bGV4O2FsaWduLWl0ZW1zOmNlbnRlcjtqdXN0aWZ5LWNvbnRlbnQ6Y2VudGVyO21pbi13aWR0aDoz
NnB4O21pbi1oZWlnaHQ6MzZweDtib3JkZXItcmFkaXVzOjUwJTtiYWNrZ3JvdW5kOnZhcigtLWNv
bnRhaW5lcik7Y29sb3I6dmFyKC0tcHJpbWFyeSl9LmZpbGUtb3BlbiBzdmd7d2lkdGg6MThweH0u
bWF0ZXJpYWwtaWNvbntmaWxsOmN1cnJlbnRDb2xvcjtzdHJva2U6bm9uZX0uY2hlY2suZXJyb3J7
YmFja2dyb3VuZDojZmZkYWQ2O2NvbG9yOiM5MzAwMGF9LmNoZWNrIHNtYWxse2Rpc3BsYXk6Ymxv
Y2s7Zm9udC1zaXplOjEycHg7b3ZlcmZsb3ctd3JhcDphbnl3aGVyZX0uZmlsZXtkaXNwbGF5OmZs
ZXg7YWxpZ24taXRlbXM6Y2VudGVyO2dhcDoxMnB4O21pbi13aWR0aDowO2ZvbnQtd2VpZ2h0OjY4
MH0uZmlsZSBzdmd7d2lkdGg6MThweDtmbGV4Om5vbmV9LmZvcm1hdCwuZGF0ZSwuc2l6ZXtmb250
LXNpemU6MTNweDtjb2xvcjp2YXIoLS1tdXRlZCl9LmRvd25sb2FkIHN2Z3t3aWR0aDoxOHB4fS5k
b3dubG9hZC1sYWJlbHt3aGl0ZS1zcGFjZTpub3dyYXB9LnN0YXR1cy1jYXJke2JvcmRlcjoxcHgg
c29saWQgdmFyKC0tb3V0bGluZSk7YmFja2dyb3VuZDp2YXIoLS1sb3cpO3BhZGRpbmc6MjRweDti
b3JkZXItcmFkaXVzOjI0cHh9LnN0YXR1cy1jYXJkLm9re2JhY2tncm91bmQ6I2Q1ZWZkZTtjb2xv
cjojMTc0YzMyfS5zdGF0dXMtY2FyZC5lcnJvcntiYWNrZ3JvdW5kOiNmZmRhZDY7Y29sb3I6Izkz
MDAwYX0uc3RhdHVzLXRpdGxle2ZvbnQtc2l6ZToyMnB4O2ZvbnQtd2VpZ2h0OjY1MDttYXJnaW4t
Ym90dG9tOjhweH0uY2hlY2tze2Rpc3BsYXk6Z3JpZDtncmlkLXRlbXBsYXRlLWNvbHVtbnM6cmVw
ZWF0KDQsbWlubWF4KDAsMWZyKSk7Z2FwOjhweDttYXJnaW46MTZweCAwfS5jaGVja3twYWRkaW5n
OjhweDtib3JkZXItcmFkaXVzOjEycHg7YmFja2dyb3VuZDp2YXIoLS1oaWdoKTtmb250LXNpemU6
MTZweDtjb2xvcjp2YXIoLS1pbmspfS5zdGF0dXMtYWN0aW9uc3tkaXNwbGF5OmZsZXg7YWxpZ24t
aXRlbXM6Y2VudGVyO2dhcDoxNnB4fW5vc2NyaXB0e2Rpc3BsYXk6YmxvY2s7Y29sb3I6IzkzMDAw
YX0KQG1lZGlhKG1heC13aWR0aDo5MDBweCl7LnJvd3tncmlkLXRlbXBsYXRlLWNvbHVtbnM6MS4z
ZnIgMWZyIDEuNWZyIC44ZnIgLjhmcn0uZG93bmxvYWR7cGFkZGluZzowO3dpZHRoOjQ0cHh9LmRv
d25sb2FkLWxhYmVse2Rpc3BsYXk6bm9uZX0uc2hlbGx7cGFkZGluZzoyMHB4fS5jaGVja3N7Z3Jp
ZC10ZW1wbGF0ZS1jb2x1bW5zOnJlcGVhdCgyLG1pbm1heCgwLDFmcikpfX0KQG1lZGlhKG1heC13
aWR0aDo2MDBweCl7LnRvcGJhcntoZWlnaHQ6NTZweDtwYWRkaW5nOjAgMTZweH0uYnJhbmR7Zm9u
dC1zaXplOjIwcHh9LmJyYW5kIGltZ3t3aWR0aDozNHB4O2hlaWdodDozNHB4fS50b3BiYXIgLmNo
aXB7ZGlzcGxheTpub25lfS5yYWlse2luc2V0OmF1dG8gMCAwO2hlaWdodDo2NHB4O3dpZHRoOmF1
dG87ZmxleC1kaXJlY3Rpb246cm93O3BhZGRpbmc6NHB4IDhweDtib3JkZXItcmlnaHQ6MDtib3Jk
ZXItdG9wOjFweCBzb2xpZCB2YXIoLS1vdXRsaW5lKTtnYXA6NHB4fS5uYXYtaXRlbXtmbGV4OjE7
bWluLWhlaWdodDo1NHB4O2JvcmRlci1yYWRpdXM6MThweH0ubmF2LWl0ZW0ubGljZW5zZXttYXJn
aW46MH0uc2hlbGx7aGVpZ2h0OmNhbGMoMTAwZHZoIC0gMTIwcHgpO21hcmdpbjowO3BhZGRpbmc6
MTZweCAxMnB4fW1haW57Z2FwOjEwcHh9LnBhZ2UtaGVhZGVye21hcmdpbi1ib3R0b206MTRweH1o
MXtmb250LXNpemU6MjhweH0uaGVyb3twYWRkaW5nOjE0cHg7bWFyZ2luLWJvdHRvbToxNHB4O2dh
cDoxMnB4fS5oZXJvIGgye2ZvbnQtc2l6ZToxN3B4fS5oZXJvIHB7Zm9udC1zaXplOjEycHh9LnFy
e3dpZHRoOjk2cHg7aGVpZ2h0Ojk2cHg7cGFkZGluZzo2cHh9LmJ1dHRvbntwYWRkaW5nOjAgMTRw
eDttaW4taGVpZ2h0OjQwcHh9LnJvd3tncmlkLXRlbXBsYXRlLWNvbHVtbnM6MS4yNWZyIDFmciAx
LjZmciAuOGZyIC42ZnI7Z2FwOjVweDtwYWRkaW5nOjAgOHB4O21pbi1oZWlnaHQ6NTRweH0uZmls
ZXtnYXA6MDtmb250LXNpemU6MTJweH0uZmlsZSBzdmd7ZGlzcGxheTpub25lfS5maWxlLWNlbGx7
Z2FwOjRweH0uZmlsZS1vcGVue21pbi13aWR0aDoyNnB4O21pbi1oZWlnaHQ6MzBweH0uZmlsZS1v
cGVuIHN2Z3t3aWR0aDoxNXB4fS5jaGVja3tmb250LXNpemU6MTRweH0uZm9ybWF0LC5kYXRlLC5z
aXple2ZvbnQtc2l6ZToxMHB4fS5kYXRle2xpbmUtaGVpZ2h0OjEuM30uZm9ybWF0e292ZXJmbG93
LXdyYXA6YW55d2hlcmV9LmRvd25sb2Fke3dpZHRoOjM2cHg7bWluLXdpZHRoOjM2cHg7bWluLWhl
aWdodDozNnB4fS5oZWFke2ZvbnQtc2l6ZTo5cHg7bWluLWhlaWdodDozNnB4fS5oZWFkPnNwYW46
bGFzdC1jaGlsZHtmb250LXNpemU6OHB4fS5maWxlc3tib3JkZXItcmFkaXVzOjE4cHh9LmNoaXB7
Zm9udC1zaXplOjExcHg7cGFkZGluZzo3cHggMTBweH0uc3RhdHVzLWNhcmR7cGFkZGluZzoxNnB4
fS5zdGF0dXMtdGl0bGV7Zm9udC1zaXplOjE4cHh9fQpAbWVkaWEobWF4LWhlaWdodDo3MjBweCl7
LnNoZWxse3BhZGRpbmctdG9wOjEycHg7cGFkZGluZy1ib3R0b206MTJweH0ucGFnZS1oZWFkZXJ7
bWFyZ2luLWJvdHRvbToxMnB4fWgxe2ZvbnQtc2l6ZTozMHB4fS5oZXJve3BhZGRpbmc6MTJweCAy
MHB4O21hcmdpbi1ib3R0b206MTJweH0uaGVybyBwe21hcmdpbi1ib3R0b206OHB4fS5xcnt3aWR0
aDoxMTJweDtoZWlnaHQ6MTEycHh9LnJvd3ttaW4taGVpZ2h0OjUwcHh9LmhlYWR7bWluLWhlaWdo
dDozNHB4fX0KQG1lZGlhKG1heC1oZWlnaHQ6NjUwcHgpIGFuZCAobWF4LXdpZHRoOjYwMHB4KXsu
ZXllYnJvdywuaGVybyBwe2Rpc3BsYXk6bm9uZX0uaGVyb3twYWRkaW5nOjEwcHh9LnFye3dpZHRo
OjgwcHg7aGVpZ2h0OjgwcHh9LnJvd3ttaW4taGVpZ2h0OjQ0cHh9LmhlYWR7bWluLWhlaWdodDoy
OHB4fS5oZXJvIGgye2ZvbnQtc2l6ZToxNXB4O21hcmdpbi1ib3R0b206NnB4fS5wYWdlLWhlYWRl
cnttYXJnaW4tYm90dG9tOjEwcHh9aDF7Zm9udC1zaXplOjI0cHh9fQoudmlld3thbmltYXRpb246
YXBwZWFyIC4yNHMgZWFzZS1vdXR9LmJ1dHRvbiwuZG93bmxvYWQsLmZpbGUtb3BlbiwubmF2LWl0
ZW17dHJhbnNpdGlvbjpiYWNrZ3JvdW5kIC4xOHMsdHJhbnNmb3JtIC4xOHN9LmJ1dHRvbjpob3Zl
ciwuZG93bmxvYWQ6aG92ZXIsLmZpbGUtb3Blbjpob3ZlcntmaWx0ZXI6YnJpZ2h0bmVzcyguOTYp
O3RyYW5zZm9ybTp0cmFuc2xhdGVZKC0xcHgpfS5idXR0b246YWN0aXZlLC5kb3dubG9hZDphY3Rp
dmUsLmZpbGUtb3BlbjphY3RpdmV7dHJhbnNmb3JtOnNjYWxlKC45Nyl9QGtleWZyYW1lcyBhcHBl
YXJ7ZnJvbXtvcGFjaXR5OjA7dHJhbnNmb3JtOnRyYW5zbGF0ZVkoOHB4KX10b3tvcGFjaXR5OjE7
dHJhbnNmb3JtOm5vbmV9fUBtZWRpYShwcmVmZXJzLXJlZHVjZWQtbW90aW9uOnJlZHVjZSl7Kiwq
OjpiZWZvcmUsKjo6YWZ0ZXJ7YW5pbWF0aW9uOm5vbmUhaW1wb3J0YW50O3RyYW5zaXRpb246bm9u
ZSFpbXBvcnRhbnR9fQo8L3N0eWxlPjwvaGVhZD48Ym9keT48aGVhZGVyIGNsYXNzPSJ0b3BiYXIi
PjxhIGNsYXNzPSJicmFuZCIgaHJlZj0iLi8iPjxpbWcgc3JjPSJmYXZpY29uLnN2ZyIgYWx0PSJT
aW5nLWJveCI+PHNwYW4+QUdTPC9zcGFuPjwvYT48c3BhbiBjbGFzcz0iY2hpcCI+VkxFU1Mgwrcg
Vk1lc3MgwrcgVHJvamFuPC9zcGFuPjwvaGVhZGVyPgo8bmF2IGNsYXNzPSJyYWlsIiBhcmlhLWxh
YmVsPSJOYXZpZ2F0aW9uIj48YSBjbGFzcz0ibmF2LWl0ZW0iIGhyZWY9IiNzdGF0dXMiIGRhdGEt
dmlldz0ic3RhdHVzIj48c3ZnIHZpZXdCb3g9IjAgMCAyNCAyNCIgYXJpYS1oaWRkZW49InRydWUi
PjxjaXJjbGUgY3g9IjEyIiBjeT0iMTIiIHI9IjkiLz48cGF0aCBkPSJtNyAxMiAzIDMgNy03Ii8+
PC9zdmc+PHNwYW4gZGF0YS1pMThuPSJzdGF0dXMiPjwvc3Bhbj48L2E+PGEgY2xhc3M9Im5hdi1p
dGVtIGFjdGl2ZSIgaHJlZj0iI3N1YnNjcmlwdGlvbnMiIGRhdGEtdmlldz0ic3Vic2NyaXB0aW9u
cyI+PHN2ZyB2aWV3Qm94PSIwIDAgMjQgMjQiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBkPSJN
NCA3aDZsMiAyaDh2MTFINFoiLz48L3N2Zz48c3BhbiBkYXRhLWkxOG49InN1YnNjcmlwdGlvbnMi
Pjwvc3Bhbj48L2E+PGEgY2xhc3M9Im5hdi1pdGVtIGxpY2Vuc2UiIGhyZWY9Imh0dHBzOi8vcmF3
LmdpdGh1YnVzZXJjb250ZW50LmNvbS9GaWF0bm9ybS9BcmdvLVNpbmdib3gvcmVmcy9oZWFkcy9t
YWluL0xJQ0VOU0UiPjxzdmcgY2xhc3M9Im1hdGVyaWFsLWljb24iIHhtbG5zPSJodHRwOi8vd3d3
LnczLm9yZy8yMDAwL3N2ZyIgaGVpZ2h0PSIyNHB4IiB2aWV3Qm94PSIwIC05NjAgOTYwIDk2MCIg
d2lkdGg9IjI0cHgiIGZpbGw9IiNlM2UzZTMiIGFyaWEtaGlkZGVuPSJ0cnVlIj48cGF0aCBkPSJN
Mzk1LTQ3NXEtMzUtMzUtMzUtODV0MzUtODVxMzUtMzUgODUtMzV0ODUgMzVxMzUgMzUgMzUgODV0
LTM1IDg1cS0zNSAzNS04NSAzNXQtODUtMzVaTTI0MC00MHYtMzA5cS0zOC00Mi01OS05NnQtMjEt
MTE1cTAtMTM0IDkzLTIyN3QyMjctOTNxMTM0IDAgMjI3IDkzdDkzIDIyN3EwIDYxLTIxIDExNXQt
NTkgOTZ2MzA5bC0yNDAtODAtMjQwIDgwWm00MTAtMzUwcTcwLTcwIDcwLTE3MHQtNzAtMTcwcS03
MC03MC0xNzAtNzB0LTE3MCA3MHEtNzAgNzAtNzAgMTcwdDcwIDE3MHE3MCA3MCAxNzAgNzB0MTcw
LTcwWk0zMjAtMTU5bDE2MC00MSAxNjAgNDF2LTEyNHEtMzUgMjAtNzUuNSAzMS41VDQ4MC0yNDBx
LTQ0IDAtODQuNS0xMS41VDMyMC0yODN2MTI0Wm0xNjAtNjJaIi8+PC9zdmc+PHNwYW4gZGF0YS1p
MThuPSJsaWNlbnNlIj48L3NwYW4+PC9hPjxhIGNsYXNzPSJuYXYtaXRlbSIgaHJlZj0iaHR0cHM6
Ly9naXRodWIuY29tL0ZpYXRub3JtL0FyZ28tU2luZ2JveCIgdGFyZ2V0PSJfYmxhbmsiIHJlbD0i
bm9vcGVuZXIgbm9yZWZlcnJlciI+PHN2ZyB2aWV3Qm94PSIwIDAgMjQgMjQiIGFyaWEtaGlkZGVu
PSJ0cnVlIj48cGF0aCBkPSJNMTUgNGg1djVNMjAgNEwxMCAxNE0xOCAxM3Y3SDRWNmg3Ii8+PC9z
dmc+R2l0SHViPC9hPjwvbmF2Pgo8ZGl2IGNsYXNzPSJzaGVsbCI+PG1haW4+PHNlY3Rpb24gY2xh
c3M9InZpZXciIGlkPSJzdWJzY3JpcHRpb25zIj48aGVhZGVyIGNsYXNzPSJwYWdlLWhlYWRlciI+
PGRpdj48cCBjbGFzcz0iZXllYnJvdyI+QVJHTy1TSU5HQk9YPC9wPjxoMSBkYXRhLWkxOG49InRp
dGxlIj5AVElUTEVAPC9oMT48L2Rpdj48c3BhbiBjbGFzcz0iY2hpcCIgZGF0YS1pMThuPSJjb3Vu
dCI+PC9zcGFuPjwvaGVhZGVyPjxkaXYgY2xhc3M9Imhlcm8iPjxkaXY+PGgyIGRhdGEtaTE4bj0i
aGVybyI+PC9oMj48cCBkYXRhLWkxOG49ImhpbnQiPjwvcD48YSBjbGFzcz0iYnV0dG9uIiBocmVm
PSJhdXRvIiBkYXRhLWkxOG49Im9wZW4iPjwvYT48L2Rpdj48YSBjbGFzcz0icXIiIGhyZWY9ImF1
dG8iPjxpbWcgc3JjPSJhdXRvLXFyLnN2ZyIgYWx0PSJRUiI+PC9hPjwvZGl2PjxkaXYgY2xhc3M9
ImZpbGVzIj48ZGl2IGNsYXNzPSJyb3cgaGVhZCIgYXJpYS1oaWRkZW49InRydWUiPjxzcGFuIGRh
dGEtaTE4bj0iZmlsZSI+PC9zcGFuPjxzcGFuIGRhdGEtaTE4bj0iZm9ybWF0Ij48L3NwYW4+PHNw
YW4gZGF0YS1pMThuPSJtb2RpZmllZCI+PC9zcGFuPjxzcGFuIGRhdGEtaTE4bj0iYnl0ZXMiPjwv
c3Bhbj48c3BhbiBkYXRhLWkxOG49ImRvd25sb2FkIj48L3NwYW4+PC9kaXY+QFJPV1NAPC9kaXY+
PC9zZWN0aW9uPgo8c2VjdGlvbiBjbGFzcz0idmlldyIgaWQ9InN0YXR1cyIgaGlkZGVuPjxoZWFk
ZXIgY2xhc3M9InBhZ2UtaGVhZGVyIj48ZGl2PjxwIGNsYXNzPSJleWVicm93Ij5BR1M8L3A+PGgx
IGRhdGEtaTE4bj0ic3RhdHVzIj48L2gxPjwvZGl2PjwvaGVhZGVyPjxkaXYgY2xhc3M9InN0YXR1
cy1jYXJkIiBpZD0ic3RhdHVzLWNhcmQiIHJvbGU9InN0YXR1cyIgYXJpYS1saXZlPSJwb2xpdGUi
PjxwIGNsYXNzPSJzdGF0dXMtdGl0bGUiIGlkPSJzdGF0dXMtdGl0bGUiPjwvcD48cCBpZD0ic3Rh
dHVzLWRldGFpbCI+PC9wPjwvZGl2PjxkaXYgY2xhc3M9ImNoZWNrcyIgaWQ9ImNoZWNrcyI+PC9k
aXY+PGRpdiBjbGFzcz0ic3RhdHVzLWFjdGlvbnMiPjxidXR0b24gY2xhc3M9ImJ1dHRvbiIgaWQ9
InJlY2hlY2siIGRhdGEtaTE4bj0icmVjaGVjayI+PC9idXR0b24+PHNwYW4gaWQ9ImNoZWNrZWQt
YXQiPjwvc3Bhbj48L2Rpdj48L3NlY3Rpb24+Cjxub3NjcmlwdD5KYXZhU2NyaXB0IGlzIHJlcXVp
cmVkIGZvciBzdGF0dXMgY2hlY2tzLjwvbm9zY3JpcHQ+PC9tYWluPjwvZGl2Pgo8c2NyaXB0Pgpj
b25zdCBsYW5nPWRvY3VtZW50LmRvY3VtZW50RWxlbWVudC5sYW5nLnN0YXJ0c1dpdGgoJ2VuJyk/
J2VuJzonemgnOwpjb25zdCB3b3Jkcz17emg6e3RpdGxlOidBR1Mg6K6i6ZiF5Lit5b+DJyxzdGF0
dXM6J+eKtuaAgScsc3Vic2NyaXB0aW9uczon6K6i6ZiFJyxsaWNlbnNlOiflvIDmupDljY/orq4n
LGNvdW50Oic1IOenjeagvOW8jycsaGVybzon5LiA5Liq6ZO+5o6l77yM6Ieq5Yqo6YCC6YWNJyxo
aW50Oifoh6rliqjpgInmi6nlrqLmiLfnq6/moLzlvI/vvIzmiJbkuIvovb3kuIvmlrnmjIflrprm
oLzlvI/jgIInLG9wZW46J+aJk+W8gOiHqumAguW6lOiuoumYhSDihpcnLGZpbGU6J+aWh+S7tics
Zm9ybWF0OifmoLzlvI8nLG1vZGlmaWVkOifkv67mlLnml7bpl7QnLGJ5dGVzOiflpKflsI8nLG9w
ZW5GaWxlOifmiZPlvIAnLGRvd25sb2FkOifkuIvovb0nLGFkYXB0aXZlOifoh6rpgILlupQnLGNs
aWVudDon5oyJ5a6i5oi356uvJyxjaGVja2luZzon5q2j5Zyo5qOA5p+l6K6i6ZiF5Lit5b+D4oCm
JyxyZWFkeTon6K6i6ZiF5Lit5b+D6L+Q6KGM5q2j5bi4JyxmYWlsZWQ6J+iuoumYheS4reW/g+aj
gOafpeWksei0pScsZGV0YWlsOiflt7Lmo4Dmn6XorqLpmIXmlofku7bjgIHlhaXlj6PlkozpobXp
naLotYTmupDjgIInLGxpbWl0ZWQ6J+atpOajgOafpeehruiupOiuoumYheS4reW/g+WPr+iuv+mX
ru+8jOS4jeS7o+ihqOiKgueCuei/nuaOpea1i+ivleOAgicscmVjaGVjazon6YeN5paw5qOA5p+l
JyxjaGVja2VkOifmo4Dmn6Xml7bpl7QnLGxvYWRpbmc6J+ato+WcqOWKoOi9veKApid9LGVuOnt0
aXRsZTonQUdTIFN1YnNjcmlwdGlvbiBDZW50ZXInLHN0YXR1czonU3RhdHVzJyxzdWJzY3JpcHRp
b25zOidTdWJzY3JpcHRpb25zJyxsaWNlbnNlOidMaWNlbnNlJyxjb3VudDonNSBmb3JtYXRzJyxo
ZXJvOidPbmUgbGluaywgdGhlIHJpZ2h0IGZvcm1hdCcsaGludDonTWF0Y2ggeW91ciBjbGllbnQg
YXV0b21hdGljYWxseSwgb3IgZG93bmxvYWQgYSBzcGVjaWZpYyBmb3JtYXQgYmVsb3cuJyxvcGVu
OidPcGVuIGFkYXB0aXZlIHN1YnNjcmlwdGlvbiDihpcnLGZpbGU6J0ZpbGUnLGZvcm1hdDonRm9y
bWF0Jyxtb2RpZmllZDonTW9kaWZpZWQnLGJ5dGVzOidTaXplJyxvcGVuRmlsZTonT3BlbicsZG93
bmxvYWQ6J0Rvd25sb2FkJyxhZGFwdGl2ZTonQWRhcHRpdmUnLGNsaWVudDonQnkgY2xpZW50Jyxj
aGVja2luZzonQ2hlY2tpbmcgdGhlIHN1YnNjcmlwdGlvbiBjZW50ZXLigKYnLHJlYWR5OidTdWJz
Y3JpcHRpb24gY2VudGVyIGlzIHJ1bm5pbmcgc3VjY2Vzc2Z1bGx5JyxmYWlsZWQ6J1N1YnNjcmlw
dGlvbiBjZW50ZXIgY2hlY2sgZmFpbGVkJyxkZXRhaWw6J1N1YnNjcmlwdGlvbiBmaWxlcywgZW5k
cG9pbnRzIGFuZCBwYWdlIGFzc2V0cyBjaGVja2VkLicsbGltaXRlZDonVGhpcyB2ZXJpZmllcyBz
dWJzY3JpcHRpb24gYWNjZXNzLCBub3QgcHJveHkgY29ubmVjdGl2aXR5LicscmVjaGVjazonQ2hl
Y2sgYWdhaW4nLGNoZWNrZWQ6J0NoZWNrZWQgYXQnLGxvYWRpbmc6J0xvYWRpbmfigKYnfX07CmNv
bnN0IHQ9d29yZHNbbGFuZ107ZG9jdW1lbnQucXVlcnlTZWxlY3RvckFsbCgnW2RhdGEtaTE4bl0n
KS5mb3JFYWNoKGU9PmUudGV4dENvbnRlbnQ9dFtlLmRhdGFzZXQuaTE4bl0pO2RvY3VtZW50LnF1
ZXJ5U2VsZWN0b3IoJ25hdicpLmFyaWFMYWJlbD1sYW5nPT09J3poJz8n5a+86IiqJzonTmF2aWdh
dGlvbic7ZG9jdW1lbnQucXVlcnlTZWxlY3RvckFsbCgnW2RhdGEtYWRhcHRpdmVdJykuZm9yRWFj
aChlPT5lLnRleHRDb250ZW50PXRbZS5kYXRhc2V0LmFkYXB0aXZlXSk7ZG9jdW1lbnQucXVlcnlT
ZWxlY3RvckFsbCgnYVtkb3dubG9hZF0gc3ZnJykuZm9yRWFjaChlPT5lLnNldEF0dHJpYnV0ZSgn
YXJpYS1oaWRkZW4nLCd0cnVlJykpO2RvY3VtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoJy5maWxlLW9w
ZW4nKS5mb3JFYWNoKGU9PntlLnNldEF0dHJpYnV0ZSgnYXJpYS1sYWJlbCcsdC5vcGVuRmlsZSsn
ICcrZS5kYXRhc2V0LmZpbGUpO2UudGl0bGU9dC5vcGVuRmlsZX0pO2RvY3VtZW50LnF1ZXJ5U2Vs
ZWN0b3JBbGwoJy5maWxlLWRvd25sb2FkJykuZm9yRWFjaChlPT5lLnNldEF0dHJpYnV0ZSgnYXJp
YS1sYWJlbCcsdC5kb3dubG9hZCsnICcrZS5kYXRhc2V0LmZpbGUpKTsKbGV0IGNoZWNrUnVubmlu
Zz1mYWxzZTsKYXN5bmMgZnVuY3Rpb24gY2hlY2tTdGF0dXMoKXtpZihjaGVja1J1bm5pbmcpcmV0
dXJuO2NoZWNrUnVubmluZz10cnVlO2RvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdyZWNoZWNrJyku
ZGlzYWJsZWQ9dHJ1ZTtjb25zdCBjYXJkPWRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdzdGF0dXMt
Y2FyZCcpO2NhcmQuY2xhc3NOYW1lPSdzdGF0dXMtY2FyZCc7ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5
SWQoJ3N0YXR1cy10aXRsZScpLnRleHRDb250ZW50PXQuY2hlY2tpbmc7ZG9jdW1lbnQuZ2V0RWxl
bWVudEJ5SWQoJ3N0YXR1cy1kZXRhaWwnKS50ZXh0Q29udGVudD10LmxpbWl0ZWQ7Y29uc3QgcHJv
YmVzPVtbJ3JhdycsJ3JhdyddLFsnYmFzZTY0JywnYmFzZTY0J10sWydjbGFzaCcsJ2NsYXNoJ10s
WydzaW5nLWJveCcsJ3NpbmctYm94J10sWydhdXRvJywnYXV0byddLFsnSFRNTCcsJ2luZGV4Lmh0
bWwnXSxbJ1NWRycsJ2Zhdmljb24uc3ZnJ10sWydRUicsJ2F1dG8tcXIuc3ZnJ11dO2NvbnN0IHJl
c3VsdHM9YXdhaXQgUHJvbWlzZS5hbGwocHJvYmVzLm1hcChhc3luYyhbbGFiZWwsdXJsXSk9Pnt0
cnl7Y29uc3QgcmVzcG9uc2U9YXdhaXQgZmV0Y2godXJsLHtjYWNoZTonbm8tc3RvcmUnLHNpZ25h
bDpBYm9ydFNpZ25hbC50aW1lb3V0KDgwMDApfSk7Y29uc3QgYm9keT1hd2FpdCByZXNwb25zZS50
ZXh0KCk7aWYoIXJlc3BvbnNlLm9rKXRocm93IEVycm9yKCdIVFRQICcrcmVzcG9uc2Uuc3RhdHVz
KTtpZighYm9keS50cmltKCkpdGhyb3cgRXJyb3IoJ0VtcHR5IHJlc3BvbnNlJyk7aWYodXJsPT09
J3NpbmctYm94Jyl7Y29uc3QgZGF0YT1KU09OLnBhcnNlKGJvZHkpO2lmKCFBcnJheS5pc0FycmF5
KGRhdGEub3V0Ym91bmRzKXx8IWRhdGEub3V0Ym91bmRzLmxlbmd0aCl0aHJvdyBFcnJvcignSW52
YWxpZCBvdXRib3VuZHMnKX1pZih1cmw9PT0ncmF3JyYmIWJvZHkudHJpbSgpLnNwbGl0KC9ccj9c
bi8pLmV2ZXJ5KGxpbmU9Pi9eKHZsZXNzfHZtZXNzfHRyb2phbik6XC9cLy8udGVzdChsaW5lKSkp
dGhyb3cgRXJyb3IoJ0ludmFsaWQgVVJJJyk7aWYodXJsPT09J2Jhc2U2NCcpe2lmKCEvXih2bGVz
c3x2bWVzc3x0cm9qYW4pOlwvXC8vLnRlc3QoYXRvYihib2R5LnRyaW0oKSkpKXRocm93IEVycm9y
KCdJbnZhbGlkIEJhc2U2NCcpfWlmKHVybD09PSdjbGFzaCcmJiEvXnByb3hpZXM6L20udGVzdChi
b2R5KSl0aHJvdyBFcnJvcignSW52YWxpZCBZQU1MJyk7aWYodXJsPT09J2F1dG8nKXtsZXQgdmFs
aWQ9ZmFsc2U7dHJ5e3ZhbGlkPS9eKHZsZXNzfHZtZXNzfHRyb2phbik6XC9cLy8udGVzdChhdG9i
KGJvZHkudHJpbSgpKSl9Y2F0Y2h7fWlmKCF2YWxpZCYmIS9ecHJveGllczovbS50ZXN0KGJvZHkp
KXtjb25zdCBkYXRhPUpTT04ucGFyc2UoYm9keSk7aWYoIUFycmF5LmlzQXJyYXkoZGF0YS5vdXRi
b3VuZHMpfHwhZGF0YS5vdXRib3VuZHMubGVuZ3RoKXRocm93IEVycm9yKCdJbnZhbGlkIHN1YnNj
cmlwdGlvbicpfX1pZih1cmw9PT0naW5kZXguaHRtbCcmJiFib2R5LmluY2x1ZGVzKCdkYXRhLXZp
ZXc9InN0YXR1cyInKSl0aHJvdyBFcnJvcignSW52YWxpZCBIVE1MJyk7aWYodXJsLmVuZHNXaXRo
KCcuc3ZnJykmJiFib2R5LmluY2x1ZGVzKCc8c3ZnJykpdGhyb3cgRXJyb3IoJ1NWRycpO3JldHVy
bntsYWJlbCxvazp0cnVlfX1jYXRjaChlcnJvcil7cmV0dXJue2xhYmVsLG9rOmZhbHNlLHJlYXNv
bjplcnJvci5uYW1lPT09J1RpbWVvdXRFcnJvcic/J1RpbWVvdXQnOmVycm9yLm1lc3NhZ2V8fCdO
ZXR3b3JrIGVycm9yJ319fSkpO2NvbnN0IG9rPXJlc3VsdHMuZXZlcnkocj0+ci5vayk7Y2FyZC5j
bGFzc0xpc3QuYWRkKG9rPydvayc6J2Vycm9yJyk7ZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3N0
YXR1cy10aXRsZScpLnRleHRDb250ZW50PW9rP3QucmVhZHk6dC5mYWlsZWQ7ZG9jdW1lbnQuZ2V0
RWxlbWVudEJ5SWQoJ3N0YXR1cy1kZXRhaWwnKS50ZXh0Q29udGVudD10LmxpbWl0ZWQ7ZG9jdW1l
bnQuZ2V0RWxlbWVudEJ5SWQoJ2NoZWNrcycpLnJlcGxhY2VDaGlsZHJlbiguLi5yZXN1bHRzLm1h
cChyPT57Y29uc3QgZT1kb2N1bWVudC5jcmVhdGVFbGVtZW50KCdkaXYnKTtlLmNsYXNzTmFtZT0n
Y2hlY2snKyhyLm9rPycnOicgZXJyb3InKTtlLnRleHRDb250ZW50PShyLm9rPyfinJMgJzon4pyX
ICcpK3IubGFiZWw7aWYoIXIub2spe2NvbnN0IHJlYXNvbj1kb2N1bWVudC5jcmVhdGVFbGVtZW50
KCdzbWFsbCcpO3JlYXNvbi50ZXh0Q29udGVudD1yLnJlYXNvbjtlLmFwcGVuZChyZWFzb24pfXJl
dHVybiBlfSkpO2RvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdjaGVja2VkLWF0JykudGV4dENvbnRl
bnQ9dC5jaGVja2VkKycgwrcgJytuZXcgRGF0ZSgpLnRvTG9jYWxlVGltZVN0cmluZyhsYW5nPT09
J3poJz8nemgtQ04nOidlbi1HQicpO2NoZWNrUnVubmluZz1mYWxzZTtkb2N1bWVudC5nZXRFbGVt
ZW50QnlJZCgncmVjaGVjaycpLmRpc2FibGVkPWZhbHNlfQpkb2N1bWVudC5nZXRFbGVtZW50QnlJ
ZCgncmVjaGVjaycpLmFkZEV2ZW50TGlzdGVuZXIoJ2NsaWNrJyxjaGVja1N0YXR1cyk7CmZ1bmN0
aW9uIG5hdmlnYXRlKCl7Y29uc3QgbmFtZT1bJ3N0YXR1cyddLmluY2x1ZGVzKGxvY2F0aW9uLmhh
c2guc2xpY2UoMSkpP2xvY2F0aW9uLmhhc2guc2xpY2UoMSk6J3N1YnNjcmlwdGlvbnMnO2RvY3Vt
ZW50LnF1ZXJ5U2VsZWN0b3JBbGwoJy52aWV3JykuZm9yRWFjaChlPT5lLmhpZGRlbj1lLmlkIT09
bmFtZSk7ZG9jdW1lbnQucXVlcnlTZWxlY3RvckFsbCgnW2RhdGEtdmlld10nKS5mb3JFYWNoKGU9
Pntjb25zdCBhY3RpdmU9ZS5kYXRhc2V0LnZpZXc9PT1uYW1lO2UuY2xhc3NMaXN0LnRvZ2dsZSgn
YWN0aXZlJyxhY3RpdmUpO2lmKGFjdGl2ZSllLnNldEF0dHJpYnV0ZSgnYXJpYS1jdXJyZW50Jywn
cGFnZScpO2Vsc2UgZS5yZW1vdmVBdHRyaWJ1dGUoJ2FyaWEtY3VycmVudCcpfSk7aWYobmFtZT09
PSdzdGF0dXMnKWNoZWNrU3RhdHVzKCl9CmRvY3VtZW50LnF1ZXJ5U2VsZWN0b3JBbGwoJ1tkYXRh
LXZpZXddJykuZm9yRWFjaChlPT5lLmFkZEV2ZW50TGlzdGVuZXIoJ2NsaWNrJyxldmVudD0+e2V2
ZW50LnByZXZlbnREZWZhdWx0KCk7bG9jYXRpb24uaGFzaD1lLmRhdGFzZXQudmlld30pKTt3aW5k
b3cuYWRkRXZlbnRMaXN0ZW5lcignaGFzaGNoYW5nZScsbmF2aWdhdGUpO25hdmlnYXRlKCk7Cjwv
c2NyaXB0PjwvYm9keT48L2h0bWw+Cg==
HTML
  )"
  for language in zh en; do
    UI_LANGUAGE="$language"
    title="AGS 订阅中心"; [[ "$language" != en ]] || title="AGS Subscription Center"
    html="${template//@LANG@/$language}"
    html="${html//@TITLE@/$title}"; html="${html//@UUID@/$UUID}"
    html="${html//@ROWS@/$(subscription_index_rows)}"
    printf '%s\n' "$html" >"$stage/index.$language.html"
  done
  cp "$stage/index.$selected.html" "$panel_temp"
  # Preserve the actual repository GPL v3 license verbatim.
  # Exact user-supplied assets/singbox-icon.svg, embedded for single-file installs.
  base64 -d >"$icon_temp" <<'SVG'
PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjE0OCA5MCA3
MjggODIwIj4KICA8ZGVmcz4KICAgIDxsaW5lYXJHcmFkaWVudCBpZD0iYmcyNSIgeDE9IjAiIHkx
PSIwIiB4Mj0iMCIgeTI9IjEiPgogICAgICA8c3RvcCBvZmZzZXQ9IjAiIHN0b3AtY29sb3I9IiMy
NDJGMzciLz4KICAgICAgPHN0b3Agb2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjMEQxMzE3Ii8+CiAg
ICA8L2xpbmVhckdyYWRpZW50PgogICAgPHJhZGlhbEdyYWRpZW50IGlkPSJzcG90MjUiIGN4PSIw
LjUiIGN5PSIwLjUiIHI9IjAuNSI+CiAgICAgIDxzdG9wIG9mZnNldD0iMCIgc3RvcC1jb2xvcj0i
IzQ2NTY1RiIgc3RvcC1vcGFjaXR5PSIwLjQ1Ii8+CiAgICAgIDxzdG9wIG9mZnNldD0iMSIgc3Rv
cC1jb2xvcj0iIzQ2NTY1RiIgc3RvcC1vcGFjaXR5PSIwIi8+CiAgICA8L3JhZGlhbEdyYWRpZW50
PgogICAgPGZpbHRlciBpZD0ic29mdDI1IiB4PSItNDAlIiB5PSItNDAlIiB3aWR0aD0iMTgwJSIg
aGVpZ2h0PSIxODAlIj4KICAgICAgPGZlR2F1c3NpYW5CbHVyIHN0ZERldmlhdGlvbj0iMTgiLz4K
ICAgIDwvZmlsdGVyPgogICAgPGxpbmVhckdyYWRpZW50IGlkPSJ0b3AyNSIgZ3JhZGllbnRVbml0
cz0idXNlclNwYWNlT25Vc2UiIHgxPSIzMzAiIHkxPSIzMjAiIHgyPSI3MDAiIHkyPSI0OTAiPgog
ICAgICA8c3RvcCBvZmZzZXQ9IjAiIHN0b3AtY29sb3I9IiM0NDU4NjMiLz4KICAgICAgPHN0b3Ag
b2Zmc2V0PSIxIiBzdG9wLWNvbG9yPSIjMzk0QzU3Ii8+CiAgICA8L2xpbmVhckdyYWRpZW50Pgog
ICAgPGxpbmVhckdyYWRpZW50IGlkPSJsZWZ0MjUiIGdyYWRpZW50VW5pdHM9InVzZXJTcGFjZU9u
VXNlIiB4MT0iMjY5LjUiIHkxPSI0ODAiIHgyPSI1MTIiIHkyPSI3MjAiPgogICAgICA8c3RvcCBv
ZmZzZXQ9IjAiIHN0b3AtY29sb3I9IiMyNjMyM0EiLz4KICAgICAgPHN0b3Agb2Zmc2V0PSIxIiBz
dG9wLWNvbG9yPSIjMUYyQTMxIi8+CiAgICA8L2xpbmVhckdyYWRpZW50PgogICAgPGxpbmVhckdy
YWRpZW50IGlkPSJyaWdodDI1IiBncmFkaWVudFVuaXRzPSJ1c2VyU3BhY2VPblVzZSIgeDE9IjUx
MiIgeTE9IjY1MCIgeDI9Ijc1NC41IiB5Mj0iNTAwIj4KICAgICAgPHN0b3Agb2Zmc2V0PSIwIiBz
dG9wLWNvbG9yPSIjMzA0MDRBIi8+CiAgICAgIDxzdG9wIG9mZnNldD0iMSIgc3RvcC1jb2xvcj0i
IzM3NDg1NCIvPgogICAgPC9saW5lYXJHcmFkaWVudD4KICAgIDxmaWx0ZXIgaWQ9ImdyYWluMjUi
IHg9IjAiIHk9IjAiIHdpZHRoPSIyODAiIGhlaWdodD0iMjgwIiBmaWx0ZXJVbml0cz0idXNlclNw
YWNlT25Vc2UiPgogICAgICA8ZmVUdXJidWxlbmNlIHR5cGU9ImZyYWN0YWxOb2lzZSIgYmFzZUZy
ZXF1ZW5jeT0iMC4yMiIgbnVtT2N0YXZlcz0iNCIgc2VlZD0iMTciIHJlc3VsdD0ibiIvPgogICAg
ICA8ZmVDb2xvck1hdHJpeCBpbj0ibiIgdHlwZT0ibWF0cml4IiB2YWx1ZXM9IjAgMCAwIDAgMSAg
MCAwIDAgMCAxICAwIDAgMCAwIDEgIDAuNDUgMCAwIDAgLTAuMSIvPgogICAgPC9maWx0ZXI+CiAg
ICA8ZmlsdGVyIGlkPSJncmFpbkQyNSIgeD0iMCIgeT0iMCIgd2lkdGg9IjI4MCIgaGVpZ2h0PSIy
ODAiIGZpbHRlclVuaXRzPSJ1c2VyU3BhY2VPblVzZSI+CiAgICAgIDxmZVR1cmJ1bGVuY2UgdHlw
ZT0iZnJhY3RhbE5vaXNlIiBiYXNlRnJlcXVlbmN5PSIwLjI4IiBudW1PY3RhdmVzPSI0IiBzZWVk
PSI0MSIgcmVzdWx0PSJuIi8+CiAgICAgIDxmZUNvbG9yTWF0cml4IGluPSJuIiB0eXBlPSJtYXRy
aXgiIHZhbHVlcz0iMCAwIDAgMCAwLjAyICAwIDAgMCAwIDAuMDUgIDAgMCAwIDAgMC4wNyAgMC40
NSAwIDAgMCAtMC4xIi8+CiAgICA8L2ZpbHRlcj4KICAgIDxjbGlwUGF0aCBpZD0iY2xpcFRvcEQi
PjxwYXRoIGQ9Ik01MTIgMjYyIDc1NC41IDQwMiA1MTIgNTQyIDI2OS41IDQwMloiLz48L2NsaXBQ
YXRoPgogICAgPGNsaXBQYXRoIGlkPSJjbGlwTGVmdEQiPjxwYXRoIGQ9Ik0yNjkuNSA0MDIgNTEy
IDU0MiA1MTIgODEyIDI2OS41IDY3MloiLz48L2NsaXBQYXRoPgogICAgPGNsaXBQYXRoIGlkPSJj
bGlwUmlnaHREIj48cGF0aCBkPSJNNTEyIDU0MiA3NTQuNSA0MDIgNzU0LjUgNjcyIDUxMiA4MTJa
Ii8+PC9jbGlwUGF0aD4KICA8L2RlZnM+CiAgPGcgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoLTIyNS4y
OCAtMjczLjI4KSBzY2FsZSgxLjQ0KSI+CjwhLS0gZGVlcCBjYXJkYm9hcmQgZmFjZXMgLS0+CiAg
PHBhdGggZD0iTTUxMiAyNjIgNzU0LjUgNDAyIDUxMiA1NDIgMjY5LjUgNDAyWiIgZmlsbD0idXJs
KCN0b3AyNSkiLz4KICA8cGF0aCBkPSJNMjY5LjUgNDAyIDUxMiA1NDIgNTEyIDgxMiAyNjkuNSA2
NzJaIiBmaWxsPSJ1cmwoI2xlZnQyNSkiLz4KICA8cGF0aCBkPSJNNTEyIDU0MiA3NTQuNSA0MDIg
NzU0LjUgNjcyIDUxMiA4MTJaIiBmaWxsPSJ1cmwoI3JpZ2h0MjUpIi8+CgogIDwhLS0gcGFwZXIg
Z3JhaW4sIGZvcmVzaG9ydGVuZWQgcGVyIGZhY2UgLS0+CiAgPGcgY2xpcC1wYXRoPSJ1cmwoI2Ns
aXBUb3BEKSI+PGcgdHJhbnNmb3JtPSJtYXRyaXgoMC44NjYgMC41IDAuODY2IC0wLjUgMjY5LjUg
NDAyKSI+CiAgICA8cmVjdCB3aWR0aD0iMjgwIiBoZWlnaHQ9IjI4MCIgZmlsdGVyPSJ1cmwoI2dy
YWluMjUpIiBvcGFjaXR5PSIwLjMwIi8+CiAgICA8cmVjdCB3aWR0aD0iMjgwIiBoZWlnaHQ9IjI4
MCIgZmlsdGVyPSJ1cmwoI2dyYWluRDI1KSIgb3BhY2l0eT0iMC4zOCIvPgogIDwvZz48L2c+CiAg
PGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXBMZWZ0RCkiPjxnIHRyYW5zZm9ybT0ibWF0cml4KDAuODY2
IDAuNSAwIDAuOTY0MjggMjY5LjUgNDAyKSI+CiAgICA8cmVjdCB3aWR0aD0iMjgwIiBoZWlnaHQ9
IjI4MCIgZmlsdGVyPSJ1cmwoI2dyYWluMjUpIiBvcGFjaXR5PSIwLjIwIi8+CiAgICA8cmVjdCB3
aWR0aD0iMjgwIiBoZWlnaHQ9IjI4MCIgZmlsdGVyPSJ1cmwoI2dyYWluRDI1KSIgb3BhY2l0eT0i
MC4zNCIvPgogIDwvZz48L2c+CiAgPGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXBSaWdodEQpIj48ZyB0
cmFuc2Zvcm09Im1hdHJpeCgwLjg2NiAtMC41IDAgMC45NjQyOCA1MTIgNTQyKSI+CiAgICA8cmVj
dCB3aWR0aD0iMjgwIiBoZWlnaHQ9IjI4MCIgZmlsdGVyPSJ1cmwoI2dyYWluMjUpIiBvcGFjaXR5
PSIwLjI1Ii8+CiAgICA8cmVjdCB3aWR0aD0iMjgwIiBoZWlnaHQ9IjI4MCIgZmlsdGVyPSJ1cmwo
I2dyYWluRDI1KSIgb3BhY2l0eT0iMC4zNCIvPgogIDwvZz48L2c+CgogIDwhLS0gbGlkIGZsYXAg
c2VhbTogdHdvIGxpZCBoYWx2ZXMsIHBhcGVyLWVkZ2UgY2F0Y2hsaWdodCAtLT4KICA8cGF0aCBk
PSJNMzkwLjc1IDQ3MiA2MzMuMjUgMzMyIiBzdHJva2U9IiMxNDFFMjQiIHN0cm9rZS13aWR0aD0i
NCIgZmlsbD0ibm9uZSIgb3BhY2l0eT0iMC45Ii8+CiAgPHBhdGggZD0iTTM5MC43NSA0NzIgNjMz
LjI1IDMzMiIgc3Ryb2tlPSIjNkU4Nzk0IiBzdHJva2Utd2lkdGg9IjIiIGZpbGw9Im5vbmUiIG9w
YWNpdHk9IjAuNyIgdHJhbnNmb3JtPSJ0cmFuc2xhdGUoMCAtMykiLz4KCiAgPCEtLSBzb2Z0IGFt
YmllbnQgb2NjbHVzaW9uIGF0IGp1bmN0aW9ucyAtLT4KICA8cGF0aCBkPSJNMjY5LjUgNDAyIDUx
MiA1NDIiIHN0cm9rZT0iIzBCMTQxQSIgc3Ryb2tlLXdpZHRoPSIxMCIgb3BhY2l0eT0iMC4yOCIg
ZmlsdGVyPSJ1cmwoI3NvZnQyNSkiIGZpbGw9Im5vbmUiLz4KICA8cGF0aCBkPSJNNTEyIDU0MiA3
NTQuNSA0MDIiIHN0cm9rZT0iIzBCMTQxQSIgc3Ryb2tlLXdpZHRoPSIxMCIgb3BhY2l0eT0iMC4y
MiIgZmlsdGVyPSJ1cmwoI3NvZnQyNSkiIGZpbGw9Im5vbmUiLz4KICA8cGF0aCBkPSJNNTEyIDU0
MiA1MTIgODEyIiBzdHJva2U9IiMwNjBEMTEiIHN0cm9rZS13aWR0aD0iOSIgb3BhY2l0eT0iMC4z
MCIgZmlsdGVyPSJ1cmwoI3NvZnQyNSkiIGZpbGw9Im5vbmUiLz4KCiAgPCEtLSBwYXBlci1lZGdl
IGhpZ2hsaWdodHMgb24gdGhlIHRvcCBlZGdlcyAtLT4KICA8cGF0aCBkPSJNNTEyIDI2MiA3NTQu
NSA0MDIiIHN0cm9rZT0iIzY2ODA4RCIgc3Ryb2tlLXdpZHRoPSIyLjUiIGZpbGw9Im5vbmUiLz4K
ICA8cGF0aCBkPSJNNTEyIDI2MiAyNjkuNSA0MDIiIHN0cm9rZT0iIzVBNzM3RiIgc3Ryb2tlLXdp
ZHRoPSIyLjUiIGZpbGw9Im5vbmUiLz4KICA8cGF0aCBkPSJNMjY5LjUgNDAyIDUxMiA1NDIgNzU0
LjUgNDAyIiBzdHJva2U9IiM0RTY3NzMiIHN0cm9rZS13aWR0aD0iMiIgZmlsbD0ibm9uZSIgb3Bh
Y2l0eT0iMC45Ii8+CiAgPHBhdGggZD0iTTUxMiA1NDIgNTEyIDgxMiIgc3Ryb2tlPSIjNDQ1OTYz
IiBzdHJva2Utd2lkdGg9IjIiIGZpbGw9Im5vbmUiIG9wYWNpdHk9IjAuOSIvPgoKICA8IS0tIG9y
aWdpbmFsIHR3by10b25lIHRhcGUsIGFsaWduZWQgdGFpbHMgLS0+CiAgPHBhdGggZD0iTTM1Ni44
IDM1MS42IDM5MC43NSAzMzIgNjMzLjI1IDQ3MiA1OTkuMyA0OTEuNloiIGZpbGw9IiM5OUFBQjUi
Lz4KICA8cGF0aCBkPSJNMzkwLjc1IDMzMiA0MjQuNyAzMTIuNCA2NjcuMiA0NTIuNCA2MzMuMjUg
NDcyWiIgZmlsbD0iI0UxRThFRCIvPgogIDxwYXRoIGQ9Ik01OTkuMyA0OTEuNiA2MzMuMjUgNDcy
IDYzMy4yNSA1OTIgNTk5LjMgNjExLjZaIiBmaWxsPSIjODI5NkExIi8+CiAgPHBhdGggZD0iTTYz
My4yNSA0NzIgNjY3LjIgNDUyLjQgNjY3LjIgNTcyLjQgNjMzLjI1IDU5MloiIGZpbGw9IiNDQ0Q2
REQiLz4KICA8IS0tIHRhcGUgc29mdCBzaGFkb3cgb250byB0aGUgcGFwZXIgLS0+CiAgPHBhdGgg
ZD0iTTM2MCAzNTggNjAyLjUgNDk4IiBzdHJva2U9IiMwMDAwMDAiIG9wYWNpdHk9IjAuMjUiIHN0
cm9rZS13aWR0aD0iNyIgZmlsdGVyPSJ1cmwoI3NvZnQyNSkiIGZpbGw9Im5vbmUiLz4KICA8L2c+
Cjwvc3ZnPgo=
SVG
  chmod 644 "$stage"/*
  for html in index.zh.html index.en.html favicon.svg index.html; do
    mv -f "$stage/$html" "$SUBSCRIPTION_DIR/$html"
  done
)

write_nginx_config() {
  local tag protocol path port socks
  ensure_nodes_config
  validate_environment
  validate_nodes_config
  write_subscription_panel
  cat >"$NGINX_CONFIG" <<EOF
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

map \$http_user_agent \$ags_subscription_file {
    default ${SUB_BASE64_FILE};
    ~*(v2rayn|v2rayng|nekobox|nekoray|throne|karing|hiddify|shadowrocket|streisand|loon|quantumult|surge|egern|v2box|foxray|kitsunebi) ${SUB_BASE64_FILE};
    ~*(clash|mihomo|stash|clash-verge|clashx|flclash|nyanpasu|surfboard) ${SUB_CLASH_FILE};
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
        alias ${SUBSCRIPTION_DIR}/;
        index index.html;
    }
    location = /${UUID}/index.html {
        default_type text/html;
        alias ${SUBSCRIPTION_DIR}/index.html;
    }
    location = /${UUID}/index.zh.html {
        default_type text/html;
        alias ${SUBSCRIPTION_DIR}/index.zh.html;
    }
    location = /${UUID}/index.en.html {
        default_type text/html;
        alias ${SUBSCRIPTION_DIR}/index.en.html;
    }
    location = /${UUID}/favicon.svg {
        default_type image/svg+xml;
        alias ${SUBSCRIPTION_DIR}/favicon.svg;
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
        default_type text/plain;
        alias ${SUB_SING_BOX_FILE};
    }
    location / { return 404; }
}
EOF
  nginx -t
}

write_services() {
  local binary config label
  binary="$(core_binary)"
  config="$(core_config)"
  label="$(core_label)"
  cat >"/etc/systemd/system/${CORE_SERVICE}.service" <<EOF
[Unit]
Description=Argo-Singbox ${label} core
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
  chmod 600 "/etc/systemd/system/${ARGO_SERVICE}.service"

  cat >"/etc/systemd/system/${TRAFFIC_SERVICE}.service" <<EOF
[Unit]
Description=Argo-Singbox 流量统计采集
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
Description=Argo-Singbox 流量统计定时器

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
    traffic_collect_fail "Sing-box Core 未运行或无法读取进程信息"
  actual_binary="$(readlink -f "/proc/${pid}/exe" 2>/dev/null || true)"
  actual_binary="${actual_binary% (deleted)}"
  [[ "${actual_binary##*/}" == "sing-box" ]] || traffic_collect_fail "当前运行进程不是 Sing-box。"
  start_time="$(awk '{print $22}' "/proc/${pid}/stat" 2>/dev/null || true)"
  [[ "$start_time" =~ ^[0-9]+$ ]] || traffic_collect_fail "无法读取 Sing-box Core 启动标识"
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
  local bytes="${1:-0}"
  [[ "$bytes" =~ ^[0-9]+$ ]] || bytes=0
  LC_ALL=C awk -v bytes="$bytes" 'BEGIN {
    split("B KiB MiB GiB TiB PiB EiB", units, " ")
    value = bytes + 0
    unit = 1
    while (unit < 7 && value >= 1024) { value /= 1024; unit++ }
    if (unit == 1) printf "%.0f B", value
    else printf "%.1f %s", value, units[unit]
  }'
}

read_traffic_totals() {
  local values=""
  if command -v sqlite3 >/dev/null 2>&1 && [[ -f "$TRAFFIC_DB" ]]; then
    values="$(sqlite3 -separator '|' "$TRAFFIC_DB" \
      "SELECT uplink,downlink FROM global_totals WHERE id=1;" 2>/dev/null || true)"
  fi
  [[ "$values" =~ ^[0-9]+\|[0-9]+$ ]] || values="0|0"
  printf '%s' "$values"
}

runtime_memory_usage() {
  local unit roots pids pid rss total=0 readable=0 incomplete=0 proc="${PROC_ROOT:-/proc}"
  roots="$({
    printf '%s\n' "$$"
    for unit in nginx "$CORE_SERVICE" "$ARGO_SERVICE" "$TRAFFIC_SERVICE" warp-svc; do
      service_process_ids "$unit"
    done
  } | awk '/^[1-9][0-9]*$/ && !seen[$0]++')"
  # MainPID 回退也覆盖 Nginx worker、采集器及管理脚本的子进程。
  pids="$(ps -eo pid=,ppid= 2>/dev/null | awk -v roots="$roots" '
    BEGIN {n=split(roots,a,"\n"); for(i=1;i<=n;i++) seen[a[i]]=1}
    {parent[$1]=$2}
    END {
      changed=1
      while(changed) {changed=0; for(p in parent) if(!seen[p] && seen[parent[p]]) {seen[p]=1; changed=1}}
      for(p in seen) if(seen[p] && p ~ /^[1-9][0-9]*$/) print p
    }' | sort -nu)"
  while IFS= read -r pid; do
    [[ -n "$pid" && -d "$proc/$pid" ]] || continue
    rss="$(awk '/^VmRSS:/{print $2; exit}' "$proc/$pid/status" 2>/dev/null || true)"
    if [[ "$rss" =~ ^[0-9]+$ ]]; then
      total=$((total + 10#$rss)); readable=$((readable + 1))
    else incomplete=1; fi
  done <<<"$pids"
  ((readable)) || { ui_printf '未知 · 进程内存不可读'; return; }
  format_traffic_bytes "$((total * 1024))"
  ((incomplete == 0)) || ui_printf ' · 部分进程不可读'
}

runtime_overview() {
  local totals upload download ipv4_details ipv6_details ip country asn isp
  local ipv6_ip ipv6_country
  totals="$(read_traffic_totals)"
  IFS='|' read -r upload download <<<"$totals"
  subsection "运行状态"
  state_value "Argo Tunnel" "$(service_status "$ARGO_SERVICE")"
  state_value "Sing-box Core" "$(service_status "$CORE_SERVICE")"
  state_value "流量采集" "$(traffic_timer_status)"
  state_value "WARP 分流" "$(warp_status)"
  state_value "h2mux" "$(multiplex_status)"
  state_value "TCP Brutal" "$(tcp_brutal_status)"
  state_value "节点概览" "$(node_overview)"
  if [[ -n "${ARGO_DOMAIN:-}" ]]; then
    key_value "Argo 域名" "$ARGO_DOMAIN"
    endpoint_value "优选入口" "$SERVER" "$SERVER_PORT"
    key_value "Argo 回源" "127.0.0.1:${ORIGIN_PORT}"
  fi
  ipv4_details="$(public_ipv4_details 2>/dev/null || true)"
  if [[ -n "$ipv4_details" ]]; then
    IFS='|' read -r ip country asn isp <<<"$ipv4_details"
    ip_value "VPS IPv4" "$ip · $country · $asn · $isp"
  else
    ip_value "VPS IPv4" "GeoJS 查询失败 · 未确认出口"
  fi
  ipv6_details="$(public_ipv6_details 2>/dev/null || true)"
  if [[ -n "$ipv6_details" ]]; then
    IFS='|' read -r ipv6_ip ipv6_country _ _ <<<"$ipv6_details"
    ip_value "VPS IPv6" "$ipv6_ip · $ipv6_country"
  else
    ip_value "VPS IPv6" "None"
  fi
  key_value "全局流量" "↑ $(format_traffic_bytes "$upload") · ↓ $(format_traffic_bytes "$download")"
  key_value "运行内存" "$(runtime_memory_usage)"
  component_version_value
}

traffic_table_header() {
  printf '  %s' "$C_BRIGHT_CYAN"
  pad_right "$(ui_text '范围')" 12
  printf '  '; pad_left "$(ui_text '上传')" 12
  printf '  '; pad_left "$(ui_text '下载')" 12
  printf '  '; pad_left "$(ui_text '合计')" 12
  printf '%s\n' "$C_RESET"
}

traffic_table_row() {
  local label up down total
  label="$(fit_text "$1" 12)"; up="$(format_traffic_bytes "$2")"
  down="$(format_traffic_bytes "$3")"
  total="$(LC_ALL=C awk -v up="$2" -v down="$3" 'BEGIN {printf "%.0f", up + down}')"
  total="$(format_traffic_bytes "$total")"
  printf '  %s%s%s  %s' "$C_BRIGHT_MAGENTA" "$label" "$C_RESET" "$C_BRIGHT_WHITE"
  pad_left "$up" 12; printf '  '; pad_left "$down" 12; printf '  '; pad_left "$total" 12
  printf '%s\n' "$C_RESET"
}

show_traffic_tables() {
  local values up down
  values="$(read_traffic_totals)"
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
  state_value "定时采集" "$({ systemctl is-active --quiet "${TRAFFIC_TIMER}.timer" && ui_printf '已启用 · 每分钟'; } || ui_printf '未启用 · 原因：定时器已停止')"
  key_value "统计起点" "${reset_at:-未知}"
  key_value "最近采集" "${last_collect:-尚未采集}"
  ((collected)) || yellow "Clash API 暂不可读 · 当前显示 SQLite 累计值"
  if ((!collected)) && [[ -s "$TRAFFIC_ERROR_FILE" ]]; then
    collect_error="$(head -n 1 "$TRAFFIC_ERROR_FILE")"
    key_value "原因" "$collect_error"
  fi
  subsection "全局统计"
  show_traffic_tables
  section "统计操作"
  menu_item 1 "刷新统计"
  menu_item 2 "重置统计"
  menu_item 0 "退出脚本"
  ui_line
  read_choice "请选择："; choice="$REPLY"
  case "$choice" in
    1) traffic_collect && green "流量统计已刷新。" ;;
    2)
      read_input "确认重置全部历史流量？[y/N]：" answer
      is_exit_input "$answer" && return 0
      is_confirmed "$answer" || { yellow "已取消重置 · 统计数据未变更"; return 0; }
      traffic_reset
      green "流量统计已重置"
      ;;
    0) exit 0 ;;
    *) die "无效选项：${choice:-空}（请输入 0、1 或 2）" ;;
  esac
}

generate_nodes() {
  local old_umask vmess_json vmess_link tag protocol path port socks encoded_path encoded_tag safe_tag vmess_path first uri_server auto_url
  local clash_early_data clash_multiplex sing_box_early_data sing_box_multiplex brutal_value
  ensure_nodes_config
  validate_environment
  validate_nodes_config
  detect_tcp_brutal
  brutal_value="$(tcp_brutal_config_value)"
  old_umask="$(umask)"
  umask 077
  uri_server="$SERVER"
  [[ "$uri_server" == *:* ]] && uri_server="[${uri_server}]"
  clash_early_data=', max-early-data: 2560, early-data-header-name: Sec-WebSocket-Protocol'
  if [[ "$MULTIPLEX_ENABLED" == "1" ]]; then
    clash_multiplex=", smux: {enabled: true, protocol: h2mux, max-streams: ${MULTIPLEX_MAX_STREAMS}, statistic: true, only-tcp: false, padding: true, brutal-opts: {enabled: ${brutal_value}, up: ${BRUTAL_UP_MBPS}, down: ${BRUTAL_DOWN_MBPS}}}"
    sing_box_multiplex="\"multiplex\":{\"enabled\":true,\"protocol\":\"h2mux\",\"max_streams\":${MULTIPLEX_MAX_STREAMS},\"padding\":true,\"brutal\":{\"enabled\":${brutal_value},\"up_mbps\":${BRUTAL_UP_MBPS},\"down_mbps\":${BRUTAL_DOWN_MBPS}}}"
  else
    clash_multiplex=', smux: {enabled: false}'
    sing_box_multiplex='"multiplex":{"enabled":false}'
  fi
  sing_box_early_data=',"max_early_data":2560,"early_data_header_name":"Sec-WebSocket-Protocol"'
  : >"$NODES_FILE"
  while IFS='|' read -r tag protocol path port socks; do
    encoded_path="%2F${path#/}"
    encoded_tag="$(uri_encode "$tag")"
    safe_tag="$(json_escape "$tag")"
    vmess_path="$path"
    case "$protocol" in
      vless) printf 'vless://%s@%s:%s?encryption=none&security=tls&sni=%s&insecure=0&allowInsecure=0&type=ws&host=%s&path=%s#%s\n' \
        "$UUID" "$uri_server" "$SERVER_PORT" "$ARGO_DOMAIN" "$ARGO_DOMAIN" "${encoded_path}%3Fed%3D2560" "$encoded_tag" >>"$NODES_FILE" ;;
      trojan) printf 'trojan://%s@%s:%s?security=tls&sni=%s&insecure=0&allowInsecure=0&type=ws&host=%s&path=%s#%s\n' \
        "$UUID" "$uri_server" "$SERVER_PORT" "$ARGO_DOMAIN" "$ARGO_DOMAIN" "${encoded_path}%3Fed%3D2560" "$encoded_tag" >>"$NODES_FILE" ;;
      vmess)
        vmess_path+="?ed=2560"
        vmess_json="{\"v\":\"2\",\"ps\":\"${safe_tag}\",\"add\":\"${SERVER}\",\"port\":\"${SERVER_PORT}\",\"id\":\"${UUID}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${ARGO_DOMAIN}\",\"path\":\"${vmess_path}\",\"tls\":\"tls\",\"sni\":\"${ARGO_DOMAIN}\",\"alpn\":\"\"}"
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
    safe_tag="$(json_escape "$tag")"
    case "$protocol" in
      vless) printf '  - {name: "%s", type: vless, server: "%s", port: %s, uuid: %s, encryption: none, udp: true, tls: true, servername: %s, alpn: [http/1.1], skip-cert-verify: false, network: ws, ws-opts: {path: "%s", headers: {Host: %s}%s}%s}\n' \
        "$safe_tag" "$SERVER" "$SERVER_PORT" "$UUID" "$ARGO_DOMAIN" "$path" "$ARGO_DOMAIN" "$clash_early_data" "$clash_multiplex" ;;
      vmess) printf '  - {name: "%s", type: vmess, server: "%s", port: %s, uuid: %s, alterId: 0, cipher: auto, udp: true, tls: true, servername: %s, alpn: [http/1.1], skip-cert-verify: false, network: ws, ws-opts: {path: "%s", headers: {Host: %s}%s}%s}\n' \
        "$safe_tag" "$SERVER" "$SERVER_PORT" "$UUID" "$ARGO_DOMAIN" "$path" "$ARGO_DOMAIN" "$clash_early_data" "$clash_multiplex" ;;
      trojan) printf '  - {name: "%s", type: trojan, server: "%s", port: %s, password: %s, udp: true, tls: true, sni: %s, alpn: [http/1.1], skip-cert-verify: false, network: ws, ws-opts: {path: "%s", headers: {Host: %s}%s}%s}\n' \
        "$safe_tag" "$SERVER" "$SERVER_PORT" "$UUID" "$ARGO_DOMAIN" "$path" "$ARGO_DOMAIN" "$clash_early_data" "$clash_multiplex" ;;
    esac
  done <"$NODES_CONFIG" >>"$SUB_CLASH_FILE"
  printf 'proxy-groups:\n  - name: PROXY\n    type: select\n    proxies:\n' >>"$SUB_CLASH_FILE"
  while IFS='|' read -r tag protocol path port socks; do
    printf '      - "%s"\n' "$(json_escape "$tag")"
  done <"$NODES_CONFIG" >>"$SUB_CLASH_FILE"
  printf 'rules:\n  - MATCH,PROXY\n' >>"$SUB_CLASH_FILE"

  printf '{"outbounds":[' >"$SUB_SING_BOX_FILE"
  first=1
  while IFS='|' read -r tag protocol path port socks; do
    safe_tag="$(json_escape "$tag")"
    ((first)) || printf ',' >>"$SUB_SING_BOX_FILE"; first=0
    case "$protocol" in
      *)
        printf '{"type":"%s","tag":"%s","server":"%s","server_port":%s,' \
          "$protocol" "$safe_tag" "$SERVER" "$SERVER_PORT" >>"$SUB_SING_BOX_FILE"
        case "$protocol" in
          trojan) printf '"password":"%s",' "$UUID" >>"$SUB_SING_BOX_FILE" ;;
          vmess) printf '"uuid":"%s","security":"auto","alter_id":0,' "$UUID" >>"$SUB_SING_BOX_FILE" ;;
          vless) printf '"uuid":"%s","flow":"",' "$UUID" >>"$SUB_SING_BOX_FILE" ;;
        esac
        printf '"tls":{"enabled":true,"server_name":"%s","insecure":false},"transport":{"type":"ws","path":"%s","headers":{"Host":"%s"}%s},' \
          "$ARGO_DOMAIN" "$path" "$ARGO_DOMAIN" "$sing_box_early_data" >>"$SUB_SING_BOX_FILE"
        printf '%s}' "$sing_box_multiplex" >>"$SUB_SING_BOX_FILE"
        ;;
    esac
  done <"$NODES_CONFIG"
  printf ']}\n' >>"$SUB_SING_BOX_FILE"
  local pretty_temp
  pretty_temp="$(mktemp "${SUBSCRIPTION_DIR}/.sing-box.XXXXXX")"
  if ! jq --indent 2 . "$SUB_SING_BOX_FILE" >"$pretty_temp"; then
    rm -f "$pretty_temp"
    return 1
  fi
  mv -f "$pretty_temp" "$SUB_SING_BOX_FILE"
  rm -f "${SUBSCRIPTION_DIR}/subscription.clash-provider.yaml" \
    "${SUBSCRIPTION_DIR}/subscription.clash-full.yaml" \
    "${SUBSCRIPTION_DIR}/subscription.sing-box-full.json"
  [[ ! -d "${DATA_DIR}/templates" ]] || rmdir "${DATA_DIR}/templates" 2>/dev/null || true
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
      "$LOCAL_SCRIPT"|"$PREVIOUS_LOCAL_SCRIPT"|"${PREVIOUS_WORK_DIR}/ags.sh"|"${LEGACY_WORK_DIR}/argo-singbox.sh")
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
    generate_nodes
    write_nginx_config
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
  local failed=0 local_failed=0 ws_failed=0 ws_unknown=0 public_code public_headers curl_status port path tag protocol socks mode="${1:-full}"
  WS_HEALTH_WARNINGS=0
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
      if [[ "$mode" == "ws" ]]; then
        ((local_failed+=1))
      else
        red "本地端口 ${port} 未监听。"
      fi
      failed=1
    fi
  done < <(printf '%s\n' "$ORIGIN_PORT" "$STATS_API_PORT"; cut -d'|' -f4 "$NODES_CONFIG")
  if [[ "$mode" == "ws" ]]; then
    if ((local_failed)); then state_value "本地端口" "未运行 · ${local_failed} 个未监听"; else state_value "本地端口" "已通过"; fi
  fi

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
      if [[ "$mode" == "ws" ]]; then ((ws_failed+=1)); else red "${path}：Cloudflare 人机挑战（HTTP ${public_code:-403}）"; fi
      failed=1
    elif [[ "$public_code" == "101" ]]; then
      [[ "$mode" != "ws" ]] && green "${path}：公网 WS 握手正常"
    elif [[ "$curl_status" -eq 28 ]]; then
      if [[ "$mode" == "ws" ]]; then ((ws_unknown+=1)); else yellow "${path}：公网传输探测超时，未视为安装失败；请用客户端实测。"; fi
    else
      if [[ "$mode" == "ws" ]]; then ((ws_failed+=1)); else red "${path}：公网传输探测失败（HTTP ${public_code:-000}）"; fi
      failed=1
    fi
  done <"$NODES_CONFIG"
  if [[ "$mode" == "ws" ]]; then
    if ((ws_failed)); then state_value "公网 WS" "失败 · ${ws_failed} 项异常"; fi
    if ((ws_unknown)); then state_value "公网 WS" "需注意 · ${ws_unknown} 项探测超时"; WS_HEALTH_WARNINGS="$ws_unknown"; fi
    if ((ws_failed == 0 && ws_unknown == 0)); then state_value "公网 WS" "已通过"; fi
  elif [[ "$failed" -ne 0 ]]; then
    yellow "请确认 Public Hostname 指向 http://localhost:${ORIGIN_PORT}，并跳过全部代理路径的 Challenge/WAF。"
  fi

  return "$failed"
}

ensure_uuid() {
  [[ -n "${UUID:-}" ]] || UUID="$(cat /proc/sys/kernel/random/uuid 2>/dev/null || true)"
  [[ -n "${UUID:-}" ]] || UUID="$(openssl rand -hex 16 | sed 's/^\(........\)\(....\)\(....\)\(....\)\(............\)$/\1-\2-\3-\4-\5/')"
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
  valid_argo_token "$value" || die "Argo Token 无效 · Token 格式检查未通过"
  ARGO_TOKEN="$value"
  if [[ -n "$ARGO_DOMAIN" ]]; then
    read_input "Argo 域名 [${ARGO_DOMAIN}]：" value
  else
    read_input "Argo 域名 [必填]：" value
  fi
  is_exit_input "$value" && return 1
  ARGO_DOMAIN="${value:-$ARGO_DOMAIN}"
  [[ -n "$ARGO_DOMAIN" ]] || die "Argo 域名无效 · 请输入有效域名"
  ensure_uuid
  read_input "UUID [${UUID}]：" value
  is_exit_input "$value" && return 1
  UUID="${value:-$UUID}"
  [[ "${UUID,,}" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]] ||
    die "UUID 无效 · 请输入标准 8-4-4-4-12 UUID"
  read_input "优选入口 [${SERVER}:${SERVER_PORT}]：" endpoint
  is_exit_input "$endpoint" && return 1
  endpoint="${endpoint:-${SERVER}:${SERVER_PORT}}"
  parse_endpoint "$endpoint"
  valid_domain "$ARGO_DOMAIN" || die "Argo 域名无效 · 请输入有效域名"
}

parse_endpoint() {
  local endpoint="$1" host port
  endpoint="${endpoint//[[:space:]]/}"
  if [[ "$endpoint" =~ ^\[([0-9A-Fa-f:]+)\](:([0-9]+))?$ ]]; then
    host="${BASH_REMATCH[1]}"; port="${BASH_REMATCH[3]:-$DEFAULT_SERVER_PORT}"
  elif [[ "$endpoint" =~ ^([^:]+):([0-9]+)$ ]]; then
    host="${BASH_REMATCH[1]}"; port="${BASH_REMATCH[2]}"
  elif [[ "$endpoint" != *:* || "$endpoint" =~ ^[0-9A-Fa-f:]+$ ]]; then
    host="$endpoint"; port="$DEFAULT_SERVER_PORT"
  else
    die "优选入口无效 · 可输入域名/IP，省略端口时使用 443"
  fi
  valid_endpoint_host "$host" || die "优选入口无效 · 可输入域名/IP，省略端口时使用 443"
  valid_port "$port" || die "优选入口端口无效 · 端口范围必须为 1–65535"
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
      "$LOCAL_SCRIPT"|"$PREVIOUS_LOCAL_SCRIPT"|"${PREVIOUS_WORK_DIR}/ags.sh"|"${LEGACY_WORK_DIR}/argo-singbox.sh") ;;
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
  migration_backup="${BACKUP_DIR}/pre-argo-singbox-namespace"
  install -d -m 700 "$migration_backup"
  for legacy_file in asb.env ags.sh argo-singbox.sh; do
    [[ -f "${WORK_DIR}/${legacy_file}" ]] && cp -a "${WORK_DIR}/${legacy_file}" "$migration_backup/"
  done
  if [[ -f "${CONFIG_DIR}/argo-singbox.env" ]]; then
    cp -a "${CONFIG_DIR}/argo-singbox.env" "$migration_backup/"
  fi
  if [[ -f "${CONFIG_DIR}/ags.env" ]]; then
    cp -a "${CONFIG_DIR}/ags.env" "$migration_backup/"
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
  local install_mode="${1:-local}" import_file="${2:-}" installer_source latest_installer
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
  if [[ -n "$import_file" ]]; then
    load_config_file "$import_file"
    ensure_uuid
    validate_environment
  else
    if ! prompt_install_values; then
      yellow "已取消安装，未写入配置。"
      rm -f "$installer_source"
      return 0
    fi
  fi
  ensure_project_layout
  ensure_nodes_config
  validate_nodes_config
  detect_arch
  install_dependencies
  ensure_warp_geosite_files
  configure_warp_proxy auto
  assert_service_names_available
  install -d -m 755 "$WORK_DIR" "$BIN_DIR"
  ensure_project_layout
  install -d -m 700 "$BACKUP_DIR"
  for file in "$ENV_FILE" "$NODES_CONFIG" "$SING_BOX_CONFIG" "$NGINX_CONFIG" \
    "$LEGACY_NGINX_CONFIG" "$OLDER_NGINX_CONFIG" "$LOCAL_SCRIPT" "$PREVIOUS_LOCAL_SCRIPT"; do
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
  printf 'project=%s\nversion=%s\n' "$PROJECT_NAME" "$VERSION" >"$MANAGED_FILE"
  save_env
  write_all_core_configs
  if [[ -f "$LEGACY_NGINX_CONFIG" ]] &&
    grep -qE '/etc/(ags|argo-singbox)/' "$LEGACY_NGINX_CONFIG"; then
    rm -f "$LEGACY_NGINX_CONFIG"
  fi
  if [[ -f "$OLDER_NGINX_CONFIG" ]] &&
    grep -q '/etc/asb/' "$OLDER_NGINX_CONFIG" &&
    grep -qE '(/asb-sub|/argo-vl|/argo-vm|/argo-tr)' "$OLDER_NGINX_CONFIG"; then
    rm -f "$OLDER_NGINX_CONFIG"
  fi
  generate_nodes
  write_nginx_config
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
    rm -f "${CONFIG_DIR}/ags.env" "${WORK_DIR}/asb.env"
    rm -f "$PREVIOUS_LOCAL_SCRIPT"
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
  runtime_overview
  key_value "节点文件" "$NODES_FILE"
  key_value "管理命令" "${COMMAND_NAME} / ${COMMAND_NAME_UPPER}"
  show_install_nodes
}

install_menu() {
  local choice
  brand "${PROJECT_NAME} · 项目安装" back
  subsection "安装方式"
  menu_item 1 "本地安装"
  menu_item 2 "在线安装"
  menu_hint "在线安装会先校验并替换本地脚本。"
  menu_item 0 "退出脚本"
  ui_line
  read_choice "请选择："; choice="$REPLY"
  case "$choice" in
    1) install_project local ;;
    2) install_project github ;;
    0) exit 0 ;;
    *) die "无效选项：${choice:-空}（请输入 0、1 或 2）" ;;
  esac
}

begin_config_change() {
  CONFIG_SNAPSHOT="$(mktemp -d)"
  cp -a "$ENV_FILE" "$NODES_CONFIG" "$SING_BOX_CONFIG" "$NGINX_CONFIG" \
    "/etc/systemd/system/${CORE_SERVICE}.service" "/etc/systemd/system/${ARGO_SERVICE}.service" \
    "/etc/systemd/system/${TRAFFIC_SERVICE}.service" "/etc/systemd/system/${TRAFFIC_TIMER}.timer" \
    "$NODES_FILE" "$SUB_FILE" "$SUB_BASE64_FILE" "$SUB_CLASH_FILE" \
    "$SUB_SING_BOX_FILE" "$SUB_AUTO_QR_FILE" \
    "${SUBSCRIPTION_DIR}/index.html" "${SUBSCRIPTION_DIR}/favicon.svg" \
    "${SUBSCRIPTION_DIR}/index.zh.html" "${SUBSCRIPTION_DIR}/index.en.html" \
    "$CONFIG_SNAPSHOT/" 2>/dev/null || true
}

apply_runtime_config() {
  local snapshot="${CONFIG_SNAPSHOT:-}" panel_file
  local success_message="${1:-配置已生效}"
  local services=(nginx "$CORE_SERVICE" "$ARGO_SERVICE")
  [[ -n "$snapshot" && -d "$snapshot" ]] || die "缺少配置事务快照。"
  info "应用配置并重启服务"
  if save_env && write_available_core_configs && generate_nodes && write_nginx_config && write_services &&
    systemctl daemon-reload &&
    systemctl restart "${services[@]}" && wait_for_services "${services[@]}"; then
    rm -rf "$snapshot"
    green "$success_message"
    return 0
  fi
  red "配置验证失败 · 正在恢复修改前配置"
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
    "$SUB_SING_BOX_FILE" "$SUB_AUTO_QR_FILE" \
    "${SUBSCRIPTION_DIR}/index.html" "${SUBSCRIPTION_DIR}/favicon.svg" \
    "${SUBSCRIPTION_DIR}/index.zh.html" "${SUBSCRIPTION_DIR}/index.en.html"
  [[ -f "$snapshot/$(basename "$NODES_FILE")" ]] && install -m 600 "$snapshot/$(basename "$NODES_FILE")" "$NODES_FILE"
  [[ -f "$snapshot/$(basename "$SUB_FILE")" ]] && install -m 644 "$snapshot/$(basename "$SUB_FILE")" "$SUB_FILE"
  [[ -f "$snapshot/$(basename "$SUB_BASE64_FILE")" ]] && install -m 644 "$snapshot/$(basename "$SUB_BASE64_FILE")" "$SUB_BASE64_FILE"
  [[ -f "$snapshot/$(basename "$SUB_CLASH_FILE")" ]] && install -m 644 "$snapshot/$(basename "$SUB_CLASH_FILE")" "$SUB_CLASH_FILE"
  [[ -f "$snapshot/$(basename "$SUB_SING_BOX_FILE")" ]] && install -m 644 "$snapshot/$(basename "$SUB_SING_BOX_FILE")" "$SUB_SING_BOX_FILE"
  [[ -f "$snapshot/$(basename "$SUB_AUTO_QR_FILE")" ]] && install -m 644 "$snapshot/$(basename "$SUB_AUTO_QR_FILE")" "$SUB_AUTO_QR_FILE"
  [[ -f "$snapshot/index.html" ]] && install -m 644 "$snapshot/index.html" "${SUBSCRIPTION_DIR}/index.html"
  [[ -f "$snapshot/favicon.svg" ]] && install -m 644 "$snapshot/favicon.svg" "${SUBSCRIPTION_DIR}/favicon.svg"
  for panel_file in index.zh.html index.en.html; do
    [[ -f "$snapshot/$panel_file" ]] && install -m 644 "$snapshot/$panel_file" "$SUBSCRIPTION_DIR/$panel_file"
  done
  rm -rf "$snapshot"
  load_env
  systemctl daemon-reload
  systemctl restart nginx "$CORE_SERVICE" "$ARGO_SERVICE" 2>/dev/null || true
  die "配置未生效 · 已恢复修改前配置"
}

import_configuration() {
  local file="$1"
  require_root
  [[ -f "$ENV_FILE" ]] || { install_project local "$file"; return; }
  load_env
  ensure_nodes_config
  load_config_file "$file"
  validate_environment
  ensure_warp_geosite_files
  configure_warp_proxy auto
  begin_config_change
  apply_runtime_config "配置导入已完成"
}

list_node_profiles() {
  local mode="${1:-compact}" tag protocol path port socks direct_ip
  direct_ip="$(public_node_egress_ip)"
  if [[ "$mode" == "spaced" ]]; then
    printf '\n'
    UI_TIGHT_SECTION=1
  fi
  subsection "节点列表"
  printf '%s%s' "$C_BOLD" "$C_BRIGHT_CYAN"
  pad_right "$(ui_text '标签')" 13; printf '  '; pad_right "$(ui_text '协议')" 6; printf '  '; pad_right "$(ui_text '传输路径')" 14
  printf '  '; pad_right "$(ui_text '端口')" 5; printf '  %s%s\n' "$(ui_text 出站)" "$C_RESET"
  printf '%s%s%s\n' "$C_DIM" '-------------  ------  --------------  -----  ------------------' "$C_RESET"
  while IFS='|' read -r tag protocol path port socks; do
    printf '%s' "$C_BRIGHT_WHITE"; fit_text "$tag" 13; printf '%s  %s' "$C_RESET" "$C_BRIGHT_BLUE"
    fit_text "$(protocol_label "$protocol")" 6; printf '%s  %s' "$C_RESET" "$C_BRIGHT_WHITE"; fit_text "$path" 14
    printf '%s  %s' "$C_RESET" "$C_BRIGHT_MAGENTA"; fit_text "$port" 5; printf '%s  %s' "$C_RESET" "$C_BRIGHT_MAGENTA"
    if [[ -n "$socks" ]]; then
      fit_text "$(node_outbound_value "$socks")" 18; printf '%s\n' "$C_RESET"
    else
      fit_text "${direct_ip:-未知}" 18; printf '%s\n' "$C_RESET"
    fi
  done <"$NODES_CONFIG"
}

add_node_profile() {
  local tag protocol path port socks default_port
  brand "${PROJECT_NAME} · 添加节点" default
  validate_environment
  validate_nodes_config
  list_node_profiles
  default_port="$(next_node_port)"
  section "节点参数"
  read_input "节点标签：" tag
  is_exit_input "$tag" && return 0
  valid_node_tag "$tag" || die "节点标签无效：不能为空、首尾不能留空，且不能包含 | 或控制字符。"
  ! awk -F'|' -v tag="$tag" '$1 == tag {found=1} END {exit !found}' "$NODES_CONFIG" || die "节点标签已存在：${tag}"
  read_input "节点协议 [VLESS/VMess/Trojan]：" protocol
  is_exit_input "$protocol" && return 0
  protocol="${protocol,,}"
  [[ "$protocol" =~ ^(vless|vmess|trojan)$ ]] || die "节点协议无效 · 仅支持 VLESS / VMess / Trojan"
  read_input "传输路径 [以 / 开头]：" path
  is_exit_input "$path" && return 0
  valid_path "$path" || die "WS 路径无效 · 必须以 / 开头"
  ! awk -F'|' -v path="$path" '$3 == path {found=1} END {exit !found}' "$NODES_CONFIG" || die "WS 路径冲突 · ${path} 已被其他节点使用"
  read_input "监听端口 [${default_port}]：" port
  is_exit_input "$port" && return 0
  port="${port:-$default_port}"
  valid_port "$port" || die "本地端口无效 · 端口范围必须为 1–65535"
  ((10#$port != 10#$ORIGIN_PORT)) || die "本地端口冲突 · ${port} 被 Argo 回源占用"
  ((10#$port != 10#$STATS_API_PORT)) || die "本地端口冲突 · ${port} 被 Clash API 占用"
  [[ "$WARP_ENABLED" != "1" || 10#$port -ne 10#$WARP_PROXY_PORT ]] ||
    die "本地端口冲突 · ${port} 被 WARP SOCKS5 占用"
  ! awk -F'|' -v port="$port" '$4 == port {found=1} END {exit !found}' "$NODES_CONFIG" || die "本地端口冲突 · ${port} 已被占用"
  read_input "节点代理 [http:// 或 socks5://user:pass@host:port；留空为 direct]：" socks
  is_exit_input "$socks" && return 0
  is_direct_outbound "$socks" || valid_socks5 "$socks" || die "节点代理无效 · 使用 http://user:pass@host:port 或 socks5://user:pass@host:port，或留空使用 direct"
  if is_direct_outbound "$socks"; then
    select_node_egress "$socks" || return 0
    socks="$NODE_EGRESS"
  fi
  begin_config_change
  printf '%s|%s|%s|%s|%s\n' "$tag" "$protocol" "$path" "$port" "$socks" >>"$NODES_CONFIG"
  validate_nodes_config
  apply_runtime_config "节点已添加：${tag}"
}

change_origin_port() {
  local value temp next_port
  brand "${PROJECT_NAME} · Argo 回源" default
  subsection "当前配置"
  key_value "回源地址" "127.0.0.1:${ORIGIN_PORT}"
  section "修改配置"
  begin_config_change
  read_input "Argo Tunnel 回源端口 [${ORIGIN_PORT}]：" value
  is_exit_input "$value" && { cancel_config_change; return 0; }
  value="${value:-$ORIGIN_PORT}"
  valid_port "$value" || die "Argo 回源端口无效 · 端口范围必须为 1–65535"
  ((10#$value != 10#$STATS_API_PORT)) || die "Argo 回源端口冲突 · ${value} 被 Clash API 占用"
  next_port="$((10#$value + 1))"
  ((next_port + $(wc -l <"$NODES_CONFIG") - 1 <= 65535)) ||
    die "端口过大，无法为全部节点顺延监听端口。"
  ! ((10#$STATS_API_PORT >= next_port && 10#$STATS_API_PORT < next_port + $(wc -l <"$NODES_CONFIG"))) ||
    die "顺延后的节点端口会占用流量统计 API 端口 ${STATS_API_PORT}。"
  if [[ "$WARP_ENABLED" == "1" ]]; then
    ((10#$WARP_PROXY_PORT != 10#$value)) ||
      die "Argo 回源端口会占用 WARP SOCKS5 端口 ${WARP_PROXY_PORT}。"
    ! ((10#$WARP_PROXY_PORT >= next_port && 10#$WARP_PROXY_PORT < next_port + $(wc -l <"$NODES_CONFIG"))) ||
      die "顺延后的节点端口会占用 WARP SOCKS5 端口 ${WARP_PROXY_PORT}。"
  fi
  temp="$(mktemp)"
  awk -F'|' -v OFS='|' -v port="$next_port" '{$4=port++; print}' "$NODES_CONFIG" >"$temp"
  install -m 600 "$temp" "$NODES_CONFIG"
  rm -f "$temp"
  ORIGIN_PORT="$value"
  apply_runtime_config
  green "Argo 回源已更新：127.0.0.1:${ORIGIN_PORT}"
  yellow "请同步确认 Cloudflare Public Hostname Service 为 http://localhost:${ORIGIN_PORT}"
}

delete_node_profile() {
  local tag temp answer
  brand "${PROJECT_NAME} · 删除节点" default
  validate_environment
  validate_nodes_config
  list_node_profiles
  section "删除操作"
  [[ "$(wc -l <"$NODES_CONFIG")" -gt 1 ]] || die "至少必须保留一个节点。"
  read_input "节点标签：" tag
  is_exit_input "$tag" && return 0
  awk -F'|' -v wanted="$tag" '$1 == wanted {found=1} END {exit !found}' "$NODES_CONFIG" || die "未找到节点：${tag}"
  read_input "确认删除节点 ${tag}？[y/N]：" answer
  is_exit_input "$answer" && return 0
  is_confirmed "$answer" || { yellow "已取消删除 · 配置未变更"; return 0; }
  begin_config_change
  temp="$(mktemp)"
  awk -F'|' -v wanted="$tag" '$1 != wanted' "$NODES_CONFIG" >"$temp"
  install -m 600 "$temp" "$NODES_CONFIG"
  rm -f "$temp"
  apply_runtime_config "节点已删除：${tag}"
}

edit_node_profile() {
  local wanted tag protocol path port socks new_tag new_protocol new_path new_port new_socks temp
  brand "${PROJECT_NAME} · 修改节点" default
  validate_environment
  validate_nodes_config
  list_node_profiles
  section "选择节点"
  tag=""
  read_input "节点标签：" wanted
  is_exit_input "$wanted" && return 0
  while IFS='|' read -r tag protocol path port socks; do
    [[ "$tag" == "$wanted" ]] && break
  done <"$NODES_CONFIG"
  [[ "${tag:-}" == "$wanted" ]] || die "未找到节点：${wanted}"
  section "新的节点参数"
  read_input "节点标签 [${tag}]：" new_tag
  is_exit_input "$new_tag" && return 0
  new_tag="${new_tag:-$tag}"
  valid_node_tag "$new_tag" || die "节点标签无效：不能为空、首尾不能留空，且不能包含 | 或控制字符。"
  ! awk -F'|' -v wanted="$wanted" -v value="$new_tag" '$1 != wanted && $1 == value {found=1} END {exit !found}' "$NODES_CONFIG" || die "节点标签已存在：${new_tag}"
  tag="$new_tag"
  read_input "节点协议 [$(protocol_label "$protocol")]：" new_protocol
  is_exit_input "$new_protocol" && return 0
  new_protocol="${new_protocol:-$protocol}"; new_protocol="${new_protocol,,}"
  [[ "$new_protocol" =~ ^(vless|vmess|trojan)$ ]] || die "节点协议无效 · 仅支持 VLESS / VMess / Trojan"
  protocol="$new_protocol"
  read_input "传输路径 [${path}]：" new_path
  is_exit_input "$new_path" && return 0
  new_path="${new_path:-$path}"
  valid_path "$new_path" || die "WS 路径无效 · 必须以 / 开头"
  ! awk -F'|' -v wanted="$wanted" -v value="$new_path" '$1 != wanted && $3 == value {found=1} END {exit !found}' "$NODES_CONFIG" || die "WS 路径冲突 · ${new_path} 已被其他节点使用"
  path="$new_path"
  read_input "监听端口 [${port}]：" new_port
  is_exit_input "$new_port" && return 0
  new_port="${new_port:-$port}"
  valid_port "$new_port" || die "本地端口无效 · 端口范围必须为 1–65535"
  ((10#$new_port != 10#$ORIGIN_PORT)) || die "本地端口冲突 · ${new_port} 被 Argo 回源占用"
  ((10#$new_port != 10#$STATS_API_PORT)) || die "本地端口冲突 · ${new_port} 被 Clash API 占用"
  [[ "$WARP_ENABLED" != "1" || 10#$new_port -ne 10#$WARP_PROXY_PORT ]] ||
    die "本地端口冲突 · ${new_port} 被 WARP SOCKS5 占用"
  ! awk -F'|' -v wanted="$wanted" -v value="$new_port" '$1 != wanted && $4 == value {found=1} END {exit !found}' "$NODES_CONFIG" || die "本地端口冲突 · ${new_port} 已被占用"
  port="$new_port"
  info "新值格式：http://user:pass@host:port 或 socks5://user:pass@host:port"
  read_input "节点代理 [Enter 保持当前；- 设为 direct]：" new_socks
  is_exit_input "$new_socks" && return 0
  [[ "$new_socks" == "-" ]] && new_socks="" || new_socks="${new_socks:-$socks}"
  is_direct_outbound "$new_socks" || valid_socks5 "$new_socks" || die "节点代理无效 · 使用 http://user:pass@host:port 或 socks5://user:pass@host:port，或输入 - 使用 direct"
  if is_direct_outbound "$new_socks"; then
    select_node_egress "$new_socks" || return 0
    new_socks="$NODE_EGRESS"
  fi
  socks="$new_socks"
  begin_config_change
  temp="$(mktemp)"
  awk -F'|' -v OFS='|' -v wanted="$wanted" -v tag="$tag" -v protocol="$protocol" \
    -v path="$path" -v port="$port" -v socks="$socks" \
    '$1 == wanted {$1=tag; $2=protocol; $3=path; $4=port; $5=socks} {print}' "$NODES_CONFIG" >"$temp"
  install -m 600 "$temp" "$NODES_CONFIG"; rm -f "$temp"
  validate_nodes_config
  apply_runtime_config "节点已修改：${tag}"
}

configure_warp_geosites() {
  local choice input category normalized output item old_ifs
  brand "${PROJECT_NAME} · WARP geosite" back
  subsection "当前规则"
  key_value "geosite 规则" "${WARP_GEOSITES:-无}"
  section "规则操作"
  menu_item 1 "添加分类"
  menu_item 2 "删除分类"
  menu_item 0 "退出脚本"
  ui_line
  read_choice "请选择："; choice="$REPLY"
  case "$choice" in
      1)
        [[ "$WARP_ENABLED" == "1" ]] || die "请先启用 WARP 分流。"
        read_input "新增分类 [如 google,openai]：" input
        is_exit_input "$input" && return 0
        [[ -n "$input" ]] || die "geosite 分类不能为空。"
        normalized="$(normalize_warp_geosites "$input")"
        begin_config_change
        WARP_GEOSITES="$(normalize_warp_geosites "${WARP_GEOSITES},${normalized}")"
        apply_runtime_config
        ;;
      2)
        [[ "$WARP_ENABLED" == "1" && -n "$WARP_GEOSITES" ]] || die "当前没有 geosite 分类。"
        read_input "要删除的分类：" category
        is_exit_input "$category" && return 0
        [[ -n "$category" ]] || die "geosite 分类不能为空。"
        normalized="$(normalize_warp_geosites "$category")"
        [[ "$normalized" != *,* ]] || die "每次只能删除一个分类。"
        output=""; old_ifs="$IFS"; IFS=','
        for item in $WARP_GEOSITES; do
          [[ "$item" == "$normalized" ]] || output+="${output:+,}${item}"
        done
        IFS="$old_ifs"
        [[ "$output" != "$WARP_GEOSITES" ]] || die "未找到 geosite 分类：${normalized}"
        [[ -n "$output$WARP_DOMAINS" ]] || die "不能删除最后一个 WARP 目标。"
        begin_config_change
        WARP_GEOSITES="$output"
        apply_runtime_config
        ;;
      0) exit 0 ;;
      *) die "无效选项：${choice:-空}（请输入 0、1 或 2）" ;;
  esac
}

configure_warp_domains() {
  local choice input domain normalized output item old_ifs
  brand "${PROJECT_NAME} · WARP 域名" back
  subsection "当前规则"
  key_value "域名规则" "${WARP_DOMAINS:-无}"
  section "规则操作"
  menu_item 1 "添加域名"
  menu_item 2 "删除域名"
  menu_item 0 "退出脚本"
  ui_line
  read_choice "请选择："; choice="$REPLY"
  case "$choice" in
      1)
        [[ "$WARP_ENABLED" == "1" ]] || die "请先启用 WARP 分流。"
        read_input "新增域名 [可用逗号分隔]：" input
        is_exit_input "$input" && return 0
        [[ -n "$input" ]] || die "新增域名不能为空。"
        normalized="$(normalize_warp_domains "$input")"
        begin_config_change
        WARP_DOMAINS="$(normalize_warp_domains "${WARP_DOMAINS},${normalized}")"
        apply_runtime_config
        ;;
      2)
        [[ "$WARP_ENABLED" == "1" && -n "$WARP_DOMAINS" ]] || die "当前没有 WARP 域名。"
        read_input "要删除的域名：" domain
        is_exit_input "$domain" && return 0
        [[ -n "$domain" ]] || die "待删除域名不能为空。"
        normalized="$(normalize_warp_domains "$domain")"
        [[ "$normalized" != *,* ]] || die "每次只能删除一个域名。"
        output=""; old_ifs="$IFS"; IFS=','
        for item in $WARP_DOMAINS; do
          [[ "$item" == "$normalized" ]] || output+="${output:+,}${item}"
        done
        IFS="$old_ifs"
        [[ "$output" != "$WARP_DOMAINS" ]] || die "未找到 WARP 域名：${normalized}"
        [[ -n "$output$WARP_GEOSITES" ]] || die "不能删除最后一个 WARP 目标。"
        begin_config_change
        WARP_DOMAINS="$output"
        apply_runtime_config
        ;;
      0) exit 0 ;;
      *) die "无效选项：${choice:-空}（请输入 0、1 或 2）" ;;
  esac
}

configure_warp() {
  local choice port targets geosites answer
  brand "${PROJECT_NAME} · WARP 分流" back
  subsection "当前状态"
  state_value "WARP" "$(warp_status)"
  key_value "SOCKS5" "127.0.0.1:${WARP_PROXY_PORT}"
  key_value "域名规则" "${WARP_DOMAINS:-无}"
  key_value "geosite 规则" "${WARP_GEOSITES:-无}"
  subsection "WARP 开关"
  menu_item 1 "启用 WARP"
  menu_item 2 "停用 WARP"
  section "分流规则"
  menu_item 3 "域名规则"
  menu_item 4 "geosite 规则"
  menu_item 0 "退出脚本"
  ui_line
  read_choice "请选择："; choice="$REPLY"
  case "$choice" in
      1)
        brand "${PROJECT_NAME} · WARP 配置" default
        subsection "当前配置"
        state_value "WARP" "$(warp_status)"
        key_value "SOCKS5 端口" "$WARP_PROXY_PORT"
        key_value "域名规则" "${WARP_DOMAINS:-无}"
        key_value "geosite 规则" "${WARP_GEOSITES:-无}"
        section "修改配置"
        read_input "WARP 本地 SOCKS5 端口 [${WARP_PROXY_PORT}]：" port
        is_exit_input "$port" && return 0
        port="${port:-$WARP_PROXY_PORT}"
        valid_port "$port" || die "WARP 代理端口无效。"
        ((10#$port != 10#$ORIGIN_PORT)) || die "WARP 代理端口不能占用 Argo 回源端口 ${ORIGIN_PORT}。"
        ((10#$port != 10#$STATS_API_PORT)) || die "WARP 代理端口不能占用流量统计 API 端口 ${STATS_API_PORT}。"
        ! awk -F'|' -v port="$port" '$4 == port {found=1} END {exit !found}' "$NODES_CONFIG" ||
          die "WARP 代理端口不能占用节点监听端口 ${port}。"
        read_input "域名规则 [逗号分隔；${WARP_DOMAINS:-无}]：" targets
        is_exit_input "$targets" && return 0
        targets="${targets:-$WARP_DOMAINS}"
        targets="$(normalize_warp_domains "$targets")"
        read_input "geosite 规则 [逗号分隔；${WARP_GEOSITES:-无}]：" geosites
        is_exit_input "$geosites" && return 0
        geosites="$(normalize_warp_geosites "${geosites:-$WARP_GEOSITES}")"
        [[ -n "$targets$geosites" ]] || die "至少需要一个域名或 geosite 分类。"
        begin_config_change
        WARP_ENABLED=1; WARP_PROXY_PORT="$port"; WARP_DOMAINS="$targets"; WARP_GEOSITES="$geosites"
        ensure_warp_geosite_files
        configure_warp_proxy
        apply_runtime_config
        ;;
      2)
        read_input "确认停用 WARP 分流？[y/N]：" answer
        is_exit_input "$answer" && return 0
        is_confirmed "$answer" || { yellow "已取消修改 · 配置未变更"; return 0; }
        begin_config_change
        WARP_ENABLED=0; WARP_DOMAINS=""; WARP_GEOSITES=""
        apply_runtime_config "WARP 分流已停用"
        ;;
      3) configure_warp_domains ;;
      4) configure_warp_geosites ;;
      0) exit 0 ;;
      *) die "无效选项：${choice:-空}（请输入 0 到 4）" ;;
  esac
}

install_tcp_brutal_module() {
  local answer installer module_archive actual_sha supported=0 packages
  tcp_brutal_preflight && supported=1
  brand "${PROJECT_NAME} · TCP Brutal 安装" default
  subsection "内核预检"
  key_value "当前内核" "${TCP_BRUTAL_CHECKED_KERNEL:-未知}"
  if ((supported)); then
    green "当前内核支持安装 TCP Brutal DKMS 模块。"
    key_value "内核头文件" "$TCP_BRUTAL_HEADERS_STATE"
    [[ -z "$TCP_BRUTAL_SUPPORT_WARNING" ]] || yellow "$TCP_BRUTAL_SUPPORT_WARNING"
  else
    red "$TCP_BRUTAL_SUPPORT_ERROR"
    if [[ "$TCP_BRUTAL_REMEDIATION" == "debian-kernel-upgrade" ]]; then
      guide_tcp_brutal_debian_kernel
    else
      menu_hint "当前环境无法安全安装 TCP Brutal，未执行任何变更。"
    fi
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
  read_input "确认安装或更新 TCP Brutal？[y/N]：" answer
  is_exit_input "$answer" && { return_notice; return 0; }
  is_confirmed "$answer" || { yellow "已取消 TCP Brutal 安装。"; return 0; }

  info "正在刷新 APT 并复核当前内核的官方安装条件..."
  apt-get update || die "APT 软件包索引更新失败，无法复核 TCP Brutal 安装条件。"
  if ! tcp_brutal_preflight; then
    red "$TCP_BRUTAL_SUPPORT_ERROR"
    if [[ "$TCP_BRUTAL_REMEDIATION" == "debian-kernel-upgrade" ]]; then
      guide_tcp_brutal_debian_kernel 1
      return 0
    fi
    die "APT 刷新后当前内核仍不满足 TCP Brutal 安装条件。"
  fi
  packages=(curl ca-certificates kmod dkms)
  DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}" ||
    die "TCP Brutal 安装依赖准备失败。"
  if [[ -n "$TCP_BRUTAL_HEADERS_PACKAGE" ]] &&
    ! DEBIAN_FRONTEND=noninteractive apt-get install -y "$TCP_BRUTAL_HEADERS_PACKAGE"; then
    red "当前运行内核的精确头文件安装失败：${TCP_BRUTAL_HEADERS_PACKAGE}"
    if tcp_brutal_debian_system && tcp_brutal_debian_meta_packages >/dev/null; then
      guide_tcp_brutal_debian_kernel 1
      return 0
    fi
    die "无法安装当前内核的精确头文件，未继续安装 TCP Brutal。"
  fi
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
  MULTIPLEX_ENABLED=1
  TCP_BRUTAL_ENABLED=1
  apply_runtime_config
  green "TCP Brutal 已安装并加载，服务端与订阅配置已同步。"
}

configure_transport_optimization() {
  local choice value new_up new_down answer
  brand "${PROJECT_NAME} · 传输优化" back
  subsection "当前状态"
  state_value "h2mux" "$(multiplex_status)"
  state_value "TCP Brutal" "$(tcp_brutal_status)"
  key_value "上传带宽" "${BRUTAL_UP_MBPS} Mbps"
  key_value "下载带宽" "${BRUTAL_DOWN_MBPS} Mbps"
  section "TCP Brutal"
  menu_item 1 "安装 / 更新 TCP Brutal"
  menu_item 2 "启用 TCP Brutal"
  menu_item 3 "停用 TCP Brutal"
  menu_item 4 "设置 Brutal 带宽"
  section "h2mux"
  menu_item 5 "启用 h2mux"
  menu_item 6 "停用 h2mux"
  menu_item 0 "退出脚本"
  ui_line
  read_choice "请选择："; choice="$REPLY"
  case "$choice" in
      1) install_tcp_brutal_module ;;
      2)
        detect_tcp_brutal
        if [[ "$IS_BRUTAL" != "true" ]]; then
          die "服务器尚未加载 brutal 模块，请先执行“安装 / 更新 TCP Brutal”。"
        fi
        begin_config_change
        MULTIPLEX_ENABLED=1
        TCP_BRUTAL_ENABLED=1
        apply_runtime_config
        green "TCP Brutal 已启用；h2mux 与 padding 已同步启用。"
        ;;
      3)
        read_input "确认停用 TCP Brutal？模块将保留。[y/N]：" answer
        is_exit_input "$answer" && return 0
        is_confirmed "$answer" || { yellow "已取消停用 · TCP Brutal 配置未变更"; return 0; }
        begin_config_change
        TCP_BRUTAL_ENABLED=0
        apply_runtime_config
        green "TCP Brutal 已停用；内核模块仍保留。"
        ;;
      5)
        begin_config_change
        MULTIPLEX_ENABLED=1
        apply_runtime_config
        green "h2mux 与 padding 已启用。"
        ;;
      6)
        read_input "确认停用 h2mux？TCP Brutal 也会同时停用。[y/N]：" answer
        is_exit_input "$answer" && return 0
        is_confirmed "$answer" || { yellow "已取消停用 · h2mux 与 TCP Brutal 配置未变更"; return 0; }
        begin_config_change
        MULTIPLEX_ENABLED=0
        TCP_BRUTAL_ENABLED=0
        apply_runtime_config
        green "h2mux、padding 与 TCP Brutal 已停用。"
        ;;
      4)
        read_input "上传带宽 Mbps [${BRUTAL_UP_MBPS}]：" value
        is_exit_input "$value" && return 0
        new_up="${value:-$BRUTAL_UP_MBPS}"
        valid_bandwidth_mbps "$new_up" || die "上传带宽无效，请输入 1 到 100000 的整数。"
        read_input "下载带宽 Mbps [${BRUTAL_DOWN_MBPS}]：" value
        is_exit_input "$value" && return 0
        new_down="${value:-$BRUTAL_DOWN_MBPS}"
        valid_bandwidth_mbps "$new_down" || die "下载带宽无效，请输入 1 到 100000 的整数。"
        begin_config_change
        BRUTAL_UP_MBPS="$new_up"
        BRUTAL_DOWN_MBPS="$new_down"
        apply_runtime_config
        ;;
      0) exit 0 ;;
      *) die "传输优化选项无效 · 请输入 0 到 6" ;;
  esac
}

configure_node_egress() {
  local ipv4_details ipv6_details ipv4_ip ipv6_ip choice selected_family
  local old_family="${OUTBOUND_IP_FAMILY:-auto}"
  ipv4_details="$(public_ipv4_details 2>/dev/null || true)"
  ipv6_details="$(public_ipv6_details 2>/dev/null || true)"
  [[ -n "$ipv4_details" ]] && IFS='|' read -r ipv4_ip _ _ _ <<<"$ipv4_details"
  [[ -n "$ipv6_details" ]] && IFS='|' read -r ipv6_ip _ _ _ <<<"$ipv6_details"

  brand "${PROJECT_NAME} · 节点落地 IP" back
  subsection "公网出口检测"
  ip_value "VPS IPv4" "${ipv4_ip:-未通过 GeoJS 确认}"
  ip_value "VPS IPv6" "${ipv6_ip:-None}"
  if [[ -n "$ipv4_details" && -n "$ipv6_details" ]]; then
    section "选择 direct 出站地址族"
    case "$old_family" in
      auto) selected_family="IPv4（默认）" ;;
      ipv4) selected_family="IPv4" ;;
      ipv6) selected_family="IPv6" ;;
    esac
    state_value "当前落地 IP" "$selected_family"
    menu_item 1 "IPv4 直连出站"
    menu_item 2 "IPv6 直连出站"
    menu_item 0 "退出脚本"
    ui_line
    read_choice "请选择节点落地 IP："; choice="$REPLY"
    case "$choice" in
      1) selected_family=ipv4 ;;
      2) selected_family=ipv6 ;;
      0) exit 0 ;;
      *) die "无效选项（请输入 0、1 或 2）" ;;
    esac
    if [[ "$old_family" == "$selected_family" ]]; then
      yellow "节点落地 IP 未变更 · 当前为 ${selected_family^^} 直连出站"
      return 0
    fi
  elif [[ -n "$ipv4_details" ]]; then
    selected_family=ipv4
    state_value "可用落地 IP" "仅检测到 IPv4 · 自动使用 IPv4"
    [[ "$old_family" == ipv6 ]] && yellow "IPv6 出口不可用 · 已改用 IPv4 直连"
  elif [[ -n "$ipv6_details" ]]; then
    selected_family=ipv6
    state_value "可用落地 IP" "仅检测到 IPv6 · 自动使用 IPv6"
    [[ "$old_family" == ipv4 ]] && yellow "IPv4 出口不可用 · 已改用 IPv6 直连"
  else
    state_value "公网出口" "GeoJS 查询失败 · 无法确认 IPv4/IPv6"
    menu_hint "探测未成功，配置未变更。"
    return 0
  fi

  [[ "$old_family" == "$selected_family" ]] && return 0
  begin_config_change
  OUTBOUND_IP_FAMILY="$selected_family"
  apply_runtime_config "节点 direct 出站已切换为 ${selected_family^^}"
}


manage_config() {
  local choice value endpoint file
  require_root
  load_env
  [[ -f "$ENV_FILE" ]] || die "${PROJECT_NAME} 尚未安装。"
  ensure_nodes_config
  brand "${PROJECT_NAME} · 配置中心" back
  subsection "Argo Tunnel"
  menu_item 1 "Token 与域名"
  menu_item 2 "优选入口"
  menu_item 3 "回源端口"
  menu_item 4 "全局 UUID"
  section "节点管理"
  menu_item 5 "节点列表"
  menu_item 6 "添加节点"
  menu_item 7 "修改节点"
  menu_item 8 "删除节点"
  section "路由分流"
  menu_item 9 "WARP 分流"
  section "传输优化"
  menu_item 10 "h2mux / TCP Brutal"
  section "配置维护"
  menu_item 11 "配置导入"
  section "网络出站"
  menu_item 12 "节点落地 IP"
  menu_item 0 "退出脚本"
  ui_line
  read_choice "请选择："; choice="$REPLY"
  case "$choice" in
      1)
        brand "${PROJECT_NAME} · Token / 域名" default
        subsection "当前配置"
        key_value "Argo 域名" "$ARGO_DOMAIN"
        state_value "Token 状态" "$([[ -n "$ARGO_TOKEN" ]] && ui_printf '已配置' || ui_printf '未配置')"
        section "修改配置"
        begin_config_change
        read_input "Argo Token [$([[ -n "$ARGO_TOKEN" ]] && ui_printf '已配置' || ui_printf '必填')]：" value
        is_exit_input "$value" && { cancel_config_change; return 0; }
        ARGO_TOKEN="${value:-$ARGO_TOKEN}"
        read_input "Argo 域名 [${ARGO_DOMAIN}]：" value
        is_exit_input "$value" && { cancel_config_change; return 0; }
        ARGO_DOMAIN="${value:-$ARGO_DOMAIN}"
        valid_argo_token "$ARGO_TOKEN" || die "Argo Token 无效 · Token 格式检查未通过"
        valid_domain "$ARGO_DOMAIN" || die "Argo 域名无效 · 请输入有效域名"
        apply_runtime_config
        ;;
      2)
        brand "${PROJECT_NAME} · 优选入口" default
        subsection "当前配置"
        endpoint_value "当前入口" "$SERVER" "$SERVER_PORT"
        section "修改配置"
        begin_config_change
        read_input "优选入口 [${SERVER}:${SERVER_PORT}]：" endpoint
        is_exit_input "$endpoint" && { cancel_config_change; return 0; }
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
        is_exit_input "$value" && { cancel_config_change; return 0; }
        value="${value:-$UUID}"
        valid_uuid "$value" || die "UUID 无效 · 请输入标准 8-4-4-4-12 UUID"
        UUID="$value"
        apply_runtime_config
        ;;
      5) list_node_profiles spaced ;;
      6) add_node_profile ;;
      7) edit_node_profile ;;
      8) delete_node_profile ;;
      9) configure_warp ;;
      10) configure_transport_optimization ;;
      11)
        read_input "配置文件绝对路径：" file
        is_exit_input "$file" && return 0
        [[ -n "$file" ]] || die "配置文件路径不能为空。"
        import_configuration "$file"
        ;;
      12) configure_node_egress ;;
      0) exit 0 ;;
      *) die "无效选项：${choice:-空}（请输入 0 到 12）" ;;
  esac
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
    output="${backup_dir}/argo-singbox-nodes-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
  fi
  [[ "$output" == /* ]] || die "备份路径必须使用绝对路径。"
  [[ "$output" != "$WORK_DIR" ]] || die "备份不能直接保存到项目根目录。"
  if [[ "$output" == "$WORK_DIR/"* && "$output" != "$BACKUP_DIR/"* ]]; then
    die "项目目录内仅允许使用默认备份目录 ${BACKUP_DIR}。"
  fi
  install -d -m 700 "$(dirname "$output")"
  [[ "$output" == *.tar.gz ]] || die "备份文件必须以 .tar.gz 结尾。"
  stage="$(mktemp -d)"
  manifest_dir="${stage}/argo-singbox-nodes-backup"
  install -d -m 700 "$manifest_dir"
  install -m 600 "$NODES_CONFIG" "${manifest_dir}/nodes.conf"
  {
    printf 'type=nodes\n'
    printf 'project=%s\n' "$PROJECT_NAME"
    printf 'version=%s\n' "$VERSION"
    printf 'created_at=%s\n' "$(date -Iseconds)"
    printf 'source=%s\n' "$NODES_CONFIG"
  } >"${manifest_dir}/manifest"
  chmod 600 "${manifest_dir}/manifest"
  temp_archive="$(mktemp --suffix=.tar.gz)"
  info "正在创建节点配置备份..."
  if ! tar -C "$stage" -czf "$temp_archive" "argo-singbox-nodes-backup"; then
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
  if [[ -f "$stage/argo-singbox-nodes-backup/nodes.conf" ]]; then
    nodes_source="$stage/argo-singbox-nodes-backup/nodes.conf"
  elif [[ -f "$stage/ags-nodes-backup/nodes.conf" ]]; then
    nodes_source="$stage/ags-nodes-backup/nodes.conf"
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
  brand "${PROJECT_NAME} · 备份恢复" back
  subsection "当前配置"
  key_value "节点配置" "$NODES_CONFIG"
  key_value "默认目录" "$BACKUP_DIR"
  subsection "备份操作"
  menu_item 1 "创建备份"
  menu_item 2 "恢复配置"
  menu_item 0 "退出脚本"
  ui_line
  read_choice "请选择："; choice="$REPLY"
  case "$choice" in
    1) backup_project ;;
    2) restore_project ;;
    0) exit 0 ;;
    *) die "无效选项：${choice:-空}（请输入 0、1 或 2）" ;;
  esac
}

colorize_journal() {
  local line level_color stamp message level
  while IFS= read -r line; do
    stamp="${line%% *}"
    message="${line#* }"
    level="LOG"; level_color="$C_BRIGHT_WHITE"
    [[ "$line" == *" INFO "* || "$line" == *" INFO["* ]] && { level="INFO"; level_color="$C_BRIGHT_GREEN"; }
    [[ "$line" == *" WARN "* || "$line" == *" WARNING "* ]] && { level="WARN"; level_color="$C_BRIGHT_YELLOW"; }
    [[ "$line" == *" ERROR "* || "$line" == *" ERROR["* ]] && { level="ERROR"; level_color="$C_BRIGHT_RED"; }
    printf '  %s' "$C_DIM"; fit_text "$stamp" 19
    printf '%s  %s' "$C_RESET" "$level_color"; pad_right "$level" 5
    printf '  '; fit_text "$message" 34
    printf '%s\n' "$C_RESET"
  done
}

filter_journal_noise() {
  grep -Ev 'infra/conf/serial: Reading config:|common/errors: The feature (WebSocket transport|VMess|Trojan).*deprecated'
}

doctor() {
  local failed=0 error_count=0 token_in_unit=0 warp_target system_memory directory mode log_errors=0 warnings=0
  local ipv4_details ipv6_details ip country asn isp ipv6_ip ipv6_country
  require_root
  load_env
  ensure_nodes_config
  system_memory="$(free -m | awk '/^Mem:/{printf "%s/%s MiB (%.0f%%)",$3,$2,$3*100/$2}')"
  ipv4_details="$(public_ipv4_details 2>/dev/null || true)"
  ipv6_details="$(public_ipv6_details 2>/dev/null || true)"
  brand "${PROJECT_NAME} · 运行诊断"
  subsection "状态报告"
  if [[ -n "$ipv4_details" ]]; then
    IFS='|' read -r ip country asn isp <<<"$ipv4_details"
    ip_value "VPS IPv4" "$ip · $country · $asn · $isp"
  else
    ip_value "VPS IPv4" "GeoJS 查询失败 · 未确认出口"
  fi
  if [[ -n "$ipv6_details" ]]; then
    IFS='|' read -r ipv6_ip ipv6_country _ _ <<<"$ipv6_details"
    ip_value "VPS IPv6" "$ipv6_ip · $ipv6_country"
  else
    ip_value "VPS IPv6" "None"
  fi
  component_version_value
  key_value "系统内存" "${system_memory:-未知}"
  key_value "运行内存" "$(runtime_memory_usage)"
  endpoint_value "优选入口" "${SERVER:-未知}" "${SERVER_PORT:-未知}"
  key_value "Argo 回源" "127.0.0.1:${ORIGIN_PORT}"
  section "配置检查"
  if validate_nodes_config && valid_uuid "$UUID" && valid_argo_token "$ARGO_TOKEN" &&
    [[ -n "$ARGO_DOMAIN" ]]; then
    state_value "AGS 配置" "已通过"
  else
    state_value "AGS 配置" "失败 · 字段或节点无效"
    failed=1; ((error_count+=1))
  fi
  if core_check >/dev/null 2>&1; then state_value "$(core_label) 配置" "已通过"; else state_value "$(core_label) 配置" "失败"; failed=1; ((error_count+=1)); fi
  if nginx -t >/dev/null 2>&1; then state_value "Nginx 配置" "已通过"; else state_value "Nginx 配置" "失败"; failed=1; ((error_count+=1)); fi
  detect_tcp_brutal
  if [[ "$TCP_BRUTAL_ENABLED" != "1" ]]; then
    state_value "TCP Brutal" "未启用 · 配置关闭"
  elif [[ "$MULTIPLEX_ENABLED" != "1" ]]; then
    state_value "TCP Brutal" "未启用 · h2mux 已关闭"
  elif [[ "$IS_BRUTAL" == "true" ]]; then
    state_value "TCP Brutal" "已通过 · 模块已加载"
  else
    state_value "TCP Brutal" "不可用 · 缺少 brutal 内核模块"
    ((warnings+=1))
  fi
  state_value "h2mux" "$(multiplex_status)"
  for directory in "$CONFIG_DIR" "$DATA_DIR" "$SUBSCRIPTION_DIR"; do
    mode="$(stat -c '%a' "$directory" 2>/dev/null || true)"
    case "$directory:$mode" in
      "$CONFIG_DIR:700") state_value "config 权限" "已通过 · 700" ;;
      "$DATA_DIR:700") state_value "data 权限" "已通过 · 700" ;;
      "$SUBSCRIPTION_DIR:755") state_value "subscriptions 权限" "已通过 · 755" ;;
      *) state_value "$(basename "$directory") 权限" "失败 · 当前 ${mode:-不存在}"; failed=1; ((error_count+=1)) ;;
    esac
  done
  [[ -f "/etc/systemd/system/${ARGO_SERVICE}.service" ]] &&
    grep -Fq -- "--token ${ARGO_TOKEN}" "/etc/systemd/system/${ARGO_SERVICE}.service" && token_in_unit=1
  if ((token_in_unit)); then state_value "Argo Token" "已通过 · 服务文件一致"; else state_value "Argo Token" "失败 · 服务文件未同步"; failed=1; ((error_count+=1)); fi
  section "服务状态"
  if systemctl is-active --quiet nginx; then state_value "Nginx" "已启用 · 运行中"; else state_value "Nginx" "未运行"; failed=1; ((error_count+=1)); fi
  if systemctl is-active --quiet "$CORE_SERVICE"; then state_value "$(core_label) Core" "已启用 · 运行中"; else state_value "$(core_label) Core" "未运行"; failed=1; ((error_count+=1)); fi
  if systemctl is-active --quiet "$ARGO_SERVICE"; then state_value "Argo Tunnel" "已启用 · 运行中"; else state_value "Argo Tunnel" "未运行"; failed=1; ((error_count+=1)); fi
  if [[ "$WARP_ENABLED" == "1" ]]; then
    if systemctl is-active --quiet warp-svc &&
      ss -lntH "sport = :${WARP_PROXY_PORT}" | grep -q .; then
      state_value "WARP 代理" "已通过 · 127.0.0.1:${WARP_PROXY_PORT}"
    else
      state_value "WARP 代理" "失败 · 服务或端口异常"
      failed=1; ((error_count+=1))
    fi
    warp_target="${WARP_DOMAINS%%,*}"
    if [[ -z "$warp_target" ]]; then
      state_value "WARP 规则" "已配置 · geosite ${WARP_GEOSITES}"
    elif curl -fsS --socks5-hostname "127.0.0.1:${WARP_PROXY_PORT}" --connect-timeout 5 \
      --max-time 10 -o /dev/null "https://${warp_target}"; then
      state_value "WARP 目标" "已通过 · ${warp_target}"
    else
      state_value "WARP 目标" "失败 · ${warp_target} 不可达"
      failed=1; ((error_count+=1))
    fi
  else
    state_value "WARP" "未启用 · 可选功能"
  fi
  if ! health_check ws; then failed=1; ((error_count+=1)); fi
  warnings=$((warnings + WS_HEALTH_WARNINGS))
  journalctl -u "$CORE_SERVICE" -u "$ARGO_SERVICE" -n 30 --no-pager -o short-iso 2>/dev/null |
    grep -qE ' ERROR | ERROR\[' && log_errors=1 || true
  section "诊断结果"
  if ((failed)); then
    red "诊断完成 · ${error_count} 个错误 · ${warnings} 个提醒"
  elif ((warnings)); then
    yellow "诊断完成 · 0 个错误 · ${warnings} 个提醒"
  else
    green "诊断完成 · 0 个错误 · 0 个提醒"
  fi
  if ((log_errors)); then
    section "近期错误日志"
    journalctl -u "$CORE_SERVICE" -u "$ARGO_SERVICE" -n 30 --no-pager -o short-iso 2>/dev/null |
      filter_journal_noise |
      grep -E ' ERROR | ERROR\[' |
      tail -n 8 |
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
  link_value "节点链接格式" "https://${ARGO_DOMAIN}/${UUID}/raw"
  link_value "自适应订阅" "$auto_url"
  link_value "Base64 订阅" "https://${ARGO_DOMAIN}/${UUID}/base64"
  link_value "Clash/Mihomo 订阅" "https://${ARGO_DOMAIN}/${UUID}/clash"
  link_value "Sing-box 订阅" "https://${ARGO_DOMAIN}/${UUID}/sing-box"
  if command -v qrencode >/dev/null 2>&1; then
    section "自适应 QR"
    qrencode -t ANSIUTF8 "$auto_url"
  fi
  section "原始节点"
  while IFS='|' read -r tag protocol path port socks; do
    IFS= read -r node <&3 || break
    ((index+=1))
    ((index > 1)) && printf '\n'
    printf '%s%s[%02d]%s %s%s%s %s· %s%s\n%s%s%s\n' \
      "$C_BOLD" "$C_BRIGHT_CYAN" "$index" "$C_RESET" "$C_BRIGHT_MAGENTA" "$tag" "$C_RESET" \
      "$C_BRIGHT_GREEN" "$(node_type_label "$protocol")" "$C_RESET" \
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
    info "正在停止 ${label}"
    systemctl disable --now "$service"
    green "${label} 已停止"
  else
    info "正在启动 ${label}"
    systemctl enable --now "$service"
    green "${label} 已启动"
  fi
}

manage_services() {
  local choice traffic_status
  require_root
  load_env
  brand "${PROJECT_NAME} · 服务管理" back
  subsection "项目服务"
  state_value "Argo Tunnel" "$(service_status "$ARGO_SERVICE")"
  state_value "Sing-box Core" "$(service_status "$CORE_SERVICE")"
  if systemctl list-unit-files "${TRAFFIC_TIMER}.timer" --no-legend 2>/dev/null | grep -q "^${TRAFFIC_TIMER}.timer"; then
    if systemctl is-active --quiet "${TRAFFIC_TIMER}.timer"; then traffic_status="已启用 · 每分钟"; else traffic_status="未启用 · 定时器已停止"; fi
  else
    traffic_status="未安装"
  fi
  state_value "流量采集" "$traffic_status"
  section "基础服务"
  state_value "Nginx" "$(service_status nginx)"
  section "服务操作"
  menu_item 1 "Argo Tunnel 启停"
  menu_item 2 "Sing-box Core 启停"
  menu_item 3 "重启核心服务"
  menu_item 0 "退出脚本"
  ui_line
  read_choice "请选择："; choice="$REPLY"
  case "$choice" in
    1) toggle_service "$ARGO_SERVICE" "Argo Tunnel" ;;
    2) toggle_service "$CORE_SERVICE" "$(core_label) Core" ;;
    3) restart_services ;;
    0) exit 0 ;;
    *) die "无效选项：${choice:-空}（请输入 0、1、2 或 3）" ;;
  esac
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
    die "Argo Tunnel 或 Sing-box Core 服务文件不存在 · 请先执行安装"
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
    read_input "确认更新 cloudflared？[y/N]：" answer
    is_exit_input "$answer" && { return_notice; return 0; }
    is_confirmed "$answer" && update_argo=1
  else
    green "cloudflared 已是目标版本。"
  fi
  section "$(core_label) 核心"
  key_value "当前版本" "${old_core:-未安装}"
  key_value "目标版本" "${new_core:-未知}"
  if [[ "$old_core" != "$new_core" ]]; then
    read_input "确认更新 $(core_label)？[y/N]：" answer
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
  brand "${PROJECT_NAME} · 系统工具" default
  section "第三方工具"
  key_value "工具" "Linux-NetSpeed"
  section "风险提示"
  yellow "第三方脚本不属于 ${PROJECT_NAME}"
  yellow "可能修改 Linux 内核、网络参数或系统磁盘"
  read_input "确认启动第三方系统脚本？[y/N]：" answer
  is_exit_input "$answer" && { return_notice; return 0; }
  is_confirmed "$answer" || { yellow "已取消启动 · 系统未变更"; return 0; }
  info "启动第三方系统脚本"
  bash <(curl -fsSL --retry 3 --connect-timeout 10 \
    https://raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcp.sh)
}

restart_services() {
  require_root
  load_env
  brand "${PROJECT_NAME} · 核心服务重启"
  subsection "重启范围"
  key_value "重启服务" "Nginx · $(core_label) · Argo Tunnel"
  info "正在重启核心服务"
  systemctl daemon-reload
  systemctl restart nginx "$CORE_SERVICE" "$ARGO_SERVICE"
  green "核心服务已重启"
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
  section "将删除"
  menu_hint "${PROJECT_NAME} 服务"
  menu_hint "Sing-box / cloudflared 项目文件"
  menu_hint "Nginx 项目配置"
  menu_hint "项目配置与统计数据"
  section "默认保留"
  menu_hint "系统 Nginx"
  menu_hint "Cloudflare WARP"
  menu_hint "第三方 BBR / 内核配置"
  read_input "输入 REMOVE 确认卸载：" answer
  is_exit_input "$answer" && { return_notice; return 0; }
  [[ "$answer" == "REMOVE" ]] || { yellow "已取消卸载 · 项目未变更"; return 0; }
  if command -v nginx >/dev/null 2>&1 ||
    dpkg-query -W -f='${Status}' nginx 2>/dev/null | grep -q 'install ok installed'; then
    read_input "确认同时卸载 Nginx？可能被其他网站使用 [y/N]：" answer
    is_exit_input "$answer" && { return_notice; return 0; }
    is_confirmed "$answer" && remove_nginx=1
  fi
  if command -v warp-cli >/dev/null 2>&1 ||
    dpkg-query -W -f='${Status}' cloudflare-warp 2>/dev/null | grep -q 'install ok installed' ||
    [[ -e /etc/apt/sources.list.d/cloudflare-client.list ||
      -e /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg ]]; then
    read_input "确认同时卸载 Cloudflare WARP 客户端、注册与软件源？[y/N]：" answer
    is_exit_input "$answer" && { return_notice; return 0; }
    is_confirmed "$answer" && remove_warp=1
  fi
  read_input "确认同时卸载 curl 等通用工具？可能被其他程序使用 [y/N]：" answer
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
    [[ "$target" == "$LOCAL_SCRIPT" || "$target" == "$PREVIOUS_LOCAL_SCRIPT" ]] && rm -f "$command_link"
  done
  remove_legacy_symlink
  rm -f "$ENV_FILE" "$NODES_CONFIG" "$SING_BOX_CONFIG" "$LOCAL_SCRIPT" \
    "$PREVIOUS_LOCAL_SCRIPT" "$MANAGED_FILE" \
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
  green "${PROJECT_NAME} 已卸载"
  exit 0
}

load_language() {
  local stored
  if [[ -r "${CONFIG_DIR}/language" ]]; then
    IFS= read -r stored <"${CONFIG_DIR}/language" || true
    case "${stored:-}" in en|zh) UI_LANGUAGE="$stored" ;; esac
  fi
  case "$UI_LANGUAGE" in en|zh) ;; *) UI_LANGUAGE=zh ;; esac
}
configure_language() {
  local choice temp
  require_root
  brand "${PROJECT_NAME} · 语言设置" default
  menu_item 1 "English"
  menu_item 2 "简体中文（默认）"
  menu_item 0 "退出脚本"
  read_choice "请选择："; choice="$REPLY"
  case "$choice" in 1) UI_LANGUAGE=en ;; 2) UI_LANGUAGE=zh ;; 0) exit 0 ;; *) die "无效选项" ;; esac
  install -d -m 700 "$CONFIG_DIR"
  temp="$(mktemp "${CONFIG_DIR}/language.XXXXXX")"
  printf '%s\n' "$UI_LANGUAGE" >"$temp"
  chmod 600 "$temp"; mv -f "$temp" "${CONFIG_DIR}/language"
  if [[ -f "$ENV_FILE" && -f "$SUB_FILE" && -d "$SUBSCRIPTION_DIR" ]]; then
    load_env
    write_subscription_panel
  fi
  green "语言设置已保存"
}
record_script_run() {
  local response mode="${1:-hit}" value_pattern
  ((SCRIPT_RUNS_REQUESTED == 0)) || return 0
  SCRIPT_RUNS_REQUESTED=1
  command -v curl >/dev/null 2>&1 || return 0
  # /hit 有副作用：限时单次请求，不重试，避免响应丢失后重复计数。
  if response="$(curl -fsS --connect-timeout 2 --max-time 3 \
    "${SCRIPT_STATS_URL}/${mode}/${SCRIPT_STATS_NAMESPACE}/${SCRIPT_STATS_KEY}" 2>/dev/null)"; then
    value_pattern='^[[:space:]]*\{[[:space:]]*"value"[[:space:]]*:[[:space:]]*(0|[1-9][0-9]*)[[:space:]]*\}[[:space:]]*$'
    [[ "$response" =~ $value_pattern ]] && SCRIPT_RUNS_TOTAL="${BASH_REMATCH[1]}"
  fi
  return 0
}
show_script_runs() {
  local UI_LABEL_WIDTH=12
  ((SCRIPT_RUNS_REQUESTED == 1 && SCRIPT_RUNS_SHOWN == 0)) || return 0
  SCRIPT_RUNS_SHOWN=1
  if [[ -n "$SCRIPT_RUNS_TOTAL" ]]; then
    key_value "脚本统计" "Executed ${SCRIPT_RUNS_TOTAL} times"
  else
    key_value "脚本统计" "Unavailable"
  fi
}

menu() {
  load_env
  control_panel
  runtime_overview
  ui_line
  brand "${PROJECT_NAME} · 控制中心" main
  UI_TIGHT_SECTION=1
  section "常用操作"
  menu_item 1 "节点订阅" "${COMMAND_NAME} -n"
  menu_item 2 "配置中心" "${COMMAND_NAME} -c"
  menu_item 3 "服务管理" "${COMMAND_NAME} -a"
  section "运行观测"
  menu_item 4 "流量统计" "${COMMAND_NAME} -t"
  menu_item 5 "运行诊断" "${COMMAND_NAME} -x"
  section "系统维护"
  menu_item 6 "组件更新" "${COMMAND_NAME} -v"
  menu_item 7 "备份恢复" "${COMMAND_NAME} -k"
  menu_item 8 "系统工具" "${COMMAND_NAME} -b"
  section "项目管理"
  menu_item 9 "项目安装" "${COMMAND_NAME} -i"
  menu_item 10 "项目卸载" "${COMMAND_NAME} -u"
  menu_item 11 "语言设置" "${COMMAND_NAME} -l"
  menu_item 0 "退出脚本"
  ui_line
  read_choice "请选择："; choice="$REPLY"
  case "$choice" in
    1) show_nodes ;;
    2) manage_config ;;
    3) manage_services ;;
    4) traffic_statistics_menu ;;
    5) doctor ;;
    6) sync_versions ;;
    7) backup_restore_menu ;;
    8) manage_bbr ;;
    9) install_menu ;;
    10) uninstall_project ;;
    11) configure_language ;;
    0) exit 0 ;;
    *) die "无效选项：${choice:-空}（请输入 0 到 11）" ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  load_language
  case "${1:-}" in
    --traffic-collect) ;;
    -i) if [[ "${2:-}" == --github-refreshed ]]; then record_script_run get; else record_script_run; fi ;;
    ""|-l|-n|-a|-c|-t|-x|-f|-v|-k|-b|-u) record_script_run ;;
    *) ;;
  esac
  trap 'cleanup_config_snapshot; printf "\n"' EXIT
  case "${1:-}" in
    -l) configure_language ;;
    -n) show_nodes ;;
    -a) manage_services ;;
    -c) manage_config ;;
    -t) traffic_statistics_menu ;;
    -x) doctor ;;
    -i)
      if [[ "${2:-}" == "--github-refreshed" ]]; then
        install_project local
      elif [[ "${2:-}" == "-f" && -n "${3:-}" && -z "${4:-}" ]]; then
        install_project local "$3"
      elif [[ -n "${2:-}" ]]; then
        die "未知安装参数：${2}"
      else
        install_menu
      fi
      ;;
    -f)
      [[ -n "${2:-}" && -z "${3:-}" ]] || die "用法：${COMMAND_NAME} -f /path/to/argo-singbox.env"
      import_configuration "$2"
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
    *) die "未知参数。可用参数：-n、-a、-c、-t、-x、-i、-f、-v、-k、-b、-u、-l。" ;;
  esac
fi
