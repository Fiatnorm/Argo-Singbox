# AGENTS.md

## 项目边界

本仓库是单内核 `Argo-Singbox`。入口固定为 `argo-singbox.sh`，运行时组件限于官方 Sing-box 与 cloudflared。`AGS` 仅用于管理命令和紧凑 UI 简称。

`reference/sba/` 是只读参考树，除非任务明确要求更新参考版本，否则不得修改、删除或提交其内容。Sing-box 核心只能来自官方 `SagerNet/sing-box` 稳定发布。

## 固定命名

- 项目名称：`Argo-Singbox`
- 项目简称：`AGS`
- 管理命令：`ags`、`AGS`
- 工作目录：`/etc/argo-singbox`
- 配置：`/etc/argo-singbox/config/argo-singbox.env`
- 核心配置：`/etc/argo-singbox/config/sing-box.json`
- Nginx：`/etc/nginx/conf.d/argo-singbox.conf`
- 服务：`argo-singbox-core`、`argo-singbox-tunnel`、`argo-singbox-traffic`
- 仓库：`Fiatnorm/Argo-Singbox`

不得把以上名称改为其他项目标识，也不得复用其他项目的目录、服务或命令。

## 功能合同

- 服务端协议固定为 VLESS、VMess、Trojan WS。
- `nodes.conf` 固定为 `标签|协议|路径|端口|SOCKS5`，五字段均由同一生成流程消费。
- 第五字段允许为空（自动直连）、`direct:ipv4` / `direct:ipv6`（直连地址族偏好）或原有 SOCKS5；新增出口选择不得增加第六字段，WARP 仍优先。
- 保留原始、Base64、Clash/Mihomo、Sing-box、自适应订阅；Sing-box 订阅是客户端格式，不是第二服务端内核。
- 保留每节点 SOCKS5、WARP 域名与 geosite 优先路由及 `WARP → 节点 SOCKS5 → direct` 顺序。
- 配置导入只能解析白名单字段，不得 `source` 外部配置；优选入口省略端口时固定使用 `443`。
- 使用 Clash API `/connections` 顶层 `uploadTotal` / `downloadTotal` + SQLite 长期计数，数据库只保留全局总量和进程基线。
- 统计必须保留每分钟采集、服务停止前最终采集、进程重启/计数回退识别、SQLite 持久累加和重置新基线。
- 保留安装、更新、诊断、备份恢复、卸载及 64 列中文终端 UI。
- 脚本版本使用 `YYYY.MM.DD` 日期格式迭代。
- CLI 每次只执行一个动作并直接退出；启动时不得清屏；所有页面统一显示 `Enter · 默认 | 0 · 取消`，菜单 Enter 取消，确认默认 No；0 直接退出脚本，不返回父菜单。运行内存为管理脚本与全部项目运行组件 RSS 合计，按 PID 去重，保留读取不完整提示。
- 三类 WS 入站默认启用带 padding 的多路复用，并提供 h2mux 与 TCP Brutal 配置启停；停用 h2mux 必须同时停用 TCP Brutal。TCP Brutal 仅在配置开启且 `brutal` 内核模块可用时启用，带宽与开关同步写入服务端和结构化订阅。
- TCP Brutal 安装必须先拒绝低于 4.9 的内核、WSL/容器、缺失当前内核模块目录、禁用 `CONFIG_MODULES`、APT/DKMS 不可用，或当前运行内核缺少且 APT 无法安装精确 `linux-headers-$(uname -r)` 的环境；不得使用其他版本头文件替代。Debian 精确头文件不可安装时，必须说明磁盘、服务、重启和 SSH 影响，分别确认是否安装发行版内核/匹配头文件以及是否立即重启，默认均不执行；重启前不得继续安装 TCP Brutal。官方 DKMS 安装器和模块包必须分别固定版本并校验 SHA256，使用本地模块包安装，成功加载模块后才重生成配置。
- 不得自动接管或删除 `/etc/afs`；从旧组合项目迁移使用节点备份恢复显式完成。

## 安全与发布

- 保持 `set -Eeuo pipefail`、LF 行尾、变量正确引用、`mktemp` 临时文件、配置 `600`、`config/data` 为 `700`、`subscriptions` 为 `755`。
- Token、UUID、域名、端口、节点与备份归档继续执行原有严格校验。
- 下载遵循超时、重试、反代与 GitHub 发布资产 SHA256 校验；官方 Sing-box 必须校验版本与 `with_clash_api` 构建标签。
- 修改脚本时同步 `VERSION`、README、终端设计稿和 `argo-singbox.sh.sha256`。
- 未经用户明确要求，不提交、推送、建仓或发布。

## 最低验证

```bash
bash -n argo-singbox.sh
bash tests/tcp-brutal-smoke.sh
bash tests/config-import-smoke.sh
bash tests/generation-smoke.sh
bash tests/traffic-global-smoke.sh
bash tests/installer-migration-smoke.sh
bash tests/ui-smoke.sh
bash tests/ui-interaction-smoke.sh
bash tests/runtime-memory-smoke.sh
bash tests/ip-egress-smoke.sh
bash tests/script-stats-smoke.sh
bash tests/script-stats-ui-smoke.sh
sha256sum -c argo-singbox.sh.sha256
git diff --check
if grep -n $'\r' argo-singbox.sh; then exit 1; fi
```

还必须检查：脚本只生成 VLESS、VMess、Trojan WS；非 TTY、`TERM=dumb`、`NO_COLOR` 无 ANSI；生成 JSON 可解析；三类节点、配置导入、WARP 域名/geosite 子页面、h2mux、TCP Brutal 开关及订阅可生成；TCP Brutal 预检覆盖支持、旧内核、WSL、容器、模块能力、APT、DKMS、精确内核头文件可安装性以及 Debian 内核升级/重启确认；Clash API 只取顶层全局计数，并覆盖累加、重启和重置逻辑。

没有真实 VPS 时，不得宣称 systemd、Nginx、Sing-box、Clash API 实时计数、Cloudflare 或公网 WS 已端到端通过。
