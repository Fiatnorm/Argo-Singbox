# AGENTS.md

## 项目边界

本仓库是单内核 `AGS`。入口固定为 `ags.sh`，运行时组件限于官方 Sing-box 与 cloudflared。

`reference/sba/` 是只读参考树，除非任务明确要求更新参考版本，否则不得修改、删除或提交其内容。Sing-box 核心只能来自官方 `SagerNet/sing-box` 稳定发布。

## 固定命名

- 项目标识：`AGS`
- 管理命令：`ags`、`AGS`
- 工作目录：`/etc/ags`
- 配置：`/etc/ags/config/ags.env`
- 核心配置：`/etc/ags/config/sing-box.json`
- Nginx：`/etc/nginx/conf.d/ags.conf`
- 服务：`ags-core`、`ags-tunnel`、`ags-traffic`
- 仓库：`Fiatnorm/AGS`

不得把以上名称改为其他项目标识，也不得复用其他项目的目录、服务或命令。

## 功能合同

- 服务端协议固定为 VLESS、VMess、Trojan WS。
- `nodes.conf` 固定为 `标签|协议|路径|端口|SOCKS5`，五字段均由同一生成流程消费。
- 保留原始、Base64、Clash/Mihomo、Sing-box、自适应订阅；Sing-box 订阅是客户端格式，不是第二服务端内核。
- 保留每节点 SOCKS5、WARP 域名优先路由及 `WARP → 节点 SOCKS5 → direct` 顺序。
- 使用 Clash API `/connections` 顶层 `uploadTotal` / `downloadTotal` + SQLite 长期计数，数据库只保留全局总量和进程基线。
- 统计必须保留每分钟采集、服务停止前最终采集、进程重启/计数回退识别、SQLite 持久累加和重置新基线。
- 保留安装、更新、诊断、备份恢复、卸载及 64 列中文终端 UI。
- 三类 WS 入站固定启用多路复用；TCP Brutal 按 `brutal` 内核模块检测结果启用，带宽参数同步写入服务端与结构化订阅。
- TCP Brutal 安装必须先拒绝低于 4.9 的内核、WSL/容器、缺失当前内核模块目录、禁用 `CONFIG_MODULES`、APT/DKMS 不可用，或当前运行内核缺少且 APT 无法安装精确 `linux-headers-$(uname -r)` 的环境；不得使用其他版本头文件替代。官方 DKMS 安装器和模块包必须分别固定版本并校验 SHA256，使用本地模块包安装，成功加载模块后才重生成配置。
- 不得自动接管或删除 `/etc/afs`；从旧组合项目迁移使用节点备份恢复显式完成。

## 安全与发布

- 保持 `set -Eeuo pipefail`、LF 行尾、变量正确引用、`mktemp` 临时文件、配置 `600`、`config/data` 为 `700`、`subscriptions` 为 `755`。
- Token、UUID、域名、端口、节点与备份归档继续执行原有严格校验。
- 下载遵循超时、重试、反代与 GitHub 发布资产 SHA256 校验；官方 Sing-box 必须校验版本与 `with_clash_api` 构建标签。
- 修改脚本时同步 `VERSION`、README、终端设计稿和 `ags.sh.sha256`。
- 未经用户明确要求，不提交、推送、建仓或发布。

## 最低验证

```bash
bash -n ags.sh
bash tests/tcp-brutal-smoke.sh
bash tests/generation-smoke.sh
bash tests/traffic-global-smoke.sh
bash tests/installer-migration-smoke.sh
sha256sum -c ags.sh.sha256
git diff --check
if grep -n $'\r' ags.sh; then exit 1; fi
```

还必须检查：脚本只生成 VLESS、VMess、Trojan WS；非 TTY、`TERM=dumb`、`NO_COLOR` 无 ANSI；生成 JSON 可解析；三类节点、h2mux、TCP Brutal 开关及订阅可生成；TCP Brutal 预检覆盖支持、旧内核、WSL、容器、模块能力、APT、DKMS 与精确内核头文件可安装性；Clash API 只取顶层全局计数，并覆盖累加、重启和重置逻辑。

没有真实 VPS 时，不得宣称 systemd、Nginx、Sing-box、Clash API 实时计数、Cloudflare 或公网 WS 已端到端通过。
