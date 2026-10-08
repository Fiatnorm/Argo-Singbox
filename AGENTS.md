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
- `nodes.conf` 固定为 `标签|协议|路径|端口|节点出站`，五字段均由同一生成流程消费。
- 节点新增、修改和删除前必须验证现有 `nodes.conf`；节点监听端口不得与其他节点、Argo 回源、Clash API 或启用中的 WARP SOCKS5 冲突。
- 保留原始、Base64、Clash/Mihomo、Sing-box、自适应订阅；Sing-box 订阅是客户端格式，不是第二服务端内核。
- 保留每节点 HTTP/SOCKS5、WARP 域名与 geosite 优先路由及 `WARP → 节点 HTTP/SOCKS5 → direct` 顺序。
- 节点默认 direct 出站优先使用可用 IPv4；仅 IPv6 出口时使用 IPv6；双栈时通过配置中心允许用户固定选择 IPv4 或 IPv6，且不影响优选入口。
- 公网 IPv4/IPv6 信息统一由 GeoJS `https://get.geojs.io/v1/ip/geo.json` 按地址族探测，运行状态单独显示 IPv4 和 IPv6。
- 配置导入只能解析白名单字段，不得 `source` 外部配置；优选入口省略端口时固定使用 `443`。
- 使用 Clash API `/connections` 顶层 `uploadTotal` / `downloadTotal` + SQLite 长期计数，数据库只保留全局总量和进程基线。
- 统计必须保留每分钟采集、服务停止前最终采集、进程重启/计数回退识别、SQLite 持久累加和重置新基线。
- 保留安装、更新、诊断、备份恢复、卸载及 64 列中英双语终端 UI（默认中文）。
- 版本控制协议：GitHub 正式发布版本使用 `YYYY.MM.DD` 日期格式，例如 `2026.09.28`；同一天内的内部测试版本使用 `YYYY.MM.DD.NN`，从 `.01` 起按修改顺序递增，例如 `2026.09.28.01`、`2026.09.28.02`。`.NN` 仅用于内部测试，不得用于 GitHub 发布；正式发布前将版本号恢复为当天的纯日期格式，并确保脚本、README、终端设计稿和校验和对应正式版本。
- 菜单 Enter 采用最安全默认项；Enter 与 0 均以高亮颜色显示。菜单或输入中的 0 均直接退出脚本，不返回上一级；危险确认 Enter 默认 No。
- 启动时不得清屏；含默认值的输入统一显示 `Enter · 默认 | 0 · 退出`。
- 脚本每次直接运行并退出时，标准输出末尾追加一行空行。
- 终端 UI 固定 64 列，菜单按“常用操作、运行观测、系统维护、项目管理”分组；配置页按功能分组，WARP 固定为开关 1/2、域名规则 3、geosite 规则 4，传输优化固定为 TCP Brutal 安装/启用/停用/带宽 1–4、h2mux 启用/停用 5/6。对象名固定使用 `Argo Tunnel`、`Sing-box Core`、`WARP`、`h2mux`、`TCP Brutal`、`SOCKS5` 与 `Clash API`，协议显示固定为 `VLESS`、`VMess`、`Trojan`。
- 成功、提醒、错误、过程信息分别使用 `✓ / ! / ✗ / •`；危险确认统一使用 `[y/N]` 并默认拒绝，项目卸载必须输入 `REMOVE`；完整 URL 与节点 URI 不得截断。
- UI 状态以对象名和状态值呈现；缺失 Brutal 模块显示 `不可用 · 缺少 brutal 内核模块`，未安装服务显示 `未安装`。诊断采用状态报告行与准确错误/提醒计数，不把正常检查逐项写成叙述句。标准输出和标准错误分别按各自 TTY 状态启用 ANSI；任一流被重定向时不得向该流写入颜色转义码。
- 正常启用和运行状态使用绿色，警告、未启用和提醒使用黄色，错误和异常使用红色。节点概览使用紫色；菜单编号、Enter、0 和项目/组件版本值使用黄色。含默认值的提示写为 `Enter · 默认 | 0 · 退出`，Enter 与 0 都须以黄色显示；控制中心字标固定为 `TERMINAL_UI_DESIGN.md` 品牌头部中的六行 ASCII 图案，最大显示宽度为 64 列，不得退化为纯文本。
- 服务页分别报告 Argo Tunnel、Sing-box Core、流量采集与 Nginx；重启操作固定显示“重启核心服务”及实际范围 `Nginx · Sing-box Core · Argo Tunnel`。备份操作固定为“创建备份 / 恢复配置”。
- 运行状态顺序固定为服务与功能状态、节点概览、Argo 域名/优选入口/回源、VPS IPv4、VPS IPv6、全局流量、运行内存、组件版本。GeoJS 的 IPv4 与 IPv6 探测分别强制使用对应地址族；落地 IP 选择只配置 Sing-box direct 出站，不得改动优选入口。运行内存统计管理脚本及项目服务实际进程 RSS 总和，覆盖 Sing-box、cloudflared、流量采集、Nginx 与已安装的 WARP；不得统计脚本文件大小或无关进程。
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
sha256sum -c argo-singbox.sh.sha256
git diff --check
if grep -n $'\r' argo-singbox.sh; then exit 1; fi
```

还必须检查：脚本只生成 VLESS、VMess、Trojan WS；非 TTY、`TERM=dumb`、`NO_COLOR` 无 ANSI；生成 JSON 可解析；三类节点、配置导入、WARP 域名/geosite 子页面、h2mux、TCP Brutal 开关及订阅可生成；TCP Brutal 预检覆盖支持、旧内核、WSL、容器、模块能力、APT、DKMS、精确内核头文件可安装性以及 Debian 内核升级/重启确认；Clash API 只取顶层全局计数，并覆盖累加、重启和重置逻辑。

没有真实 VPS 时，不得宣称 systemd、Nginx、Sing-box、Clash API 实时计数、Cloudflare 或公网 WS 已端到端通过。

语言通过 `ags -l` 或控制中心 11 设置，保存至 config/language。中文提示合同对应 zh，英语对应 en。系统环境单行显示，内核只显示数字版本；字段值完整单行显示；品牌标题保持单行。第五字段新增认证 http:// 和 socks5:// URL，同时保留旧 SOCKS5 与 direct:ipv4/ipv6。

用户指定的品牌标题保持单行显示；普通字段使用 18 列标签和 2 列间距；系统环境单行显示数字内核版本。现代 Sing-box 配置使用 domain_resolver，不依赖 domain_strategy 的废弃兼容开关。

## 2026.10.07 排版修订

- 默认中文，已显式保存的语言选择继续有效；中文和英文使用同一布局。
- 字标首行之前不额外输出空行。顶部信息标签占 12 个显示列，后跟两个空格，与标题版本号同在第 15 列；其余键值标签占 18 列，后跟两个空格，值起始列为 21。使用 UTF-8 字符码点计算显示宽度，避免 locale 改变中文宽度或误判英文。
- 品牌、功能特性、系统环境、脚本统计各占一行。系统环境示例为 `Debian GNU/Linux 13 · amd64 · Kernel 6.12.101`，不显示 `+deb13-amd64` 构建后缀。
- 执行次数始终为 `Executed N times`，失败为 `Unavailable`，不会人为递增 API 返回的次数。
- 删除运行状态中的节点落地 IP 行；保留配置页的直连地址族功能。组件版本在运行状态下显示为 `Sing-box 1.13.18 · cloudflared 2026.7.3`，只有数字版本为黄色，组件名和分隔符为白色。
- 蓝色分隔线及页面 Enter/0 提示保持 64 列；信息字段不因这条线而截断或换行。
- 内存采用唯一 PID 的 RSS 总和：管理脚本、Nginx master/workers、Sing-box、cloudflared、活跃流量采集及 SQLite 子进程、已安装 WARP。重叠 MainPID/cgroup/后代 PID 只算一次。SQLite 数据库文件不是进程内存；库页已经计入进程 RSS。RSS 可能包含各进程共享页，不能视为去重后的物理内存或 PSS；不可读进程会标记统计不完整。

## 2026.10.07 紧凑布局补充

顶部标题为 `Argo-Singbox  v2026.10.08 · Argo Tunnel · Sing-box Core`。功能特性、系统环境和执行次数的值从第 15 列开始，与标题版本号对齐；运行状态和普通字段从第 21 列开始。系统名称使用 NAME 和 VERSION_ID，省略发行代号；执行次数仍为 API 实际返回的 `Executed N times`。组件版本仅显示 `Sing-box 1.13.18 · cloudflared 2026.7.3`，仅数字为黄色。菜单、Enter/0 提示和 64 列分隔线保持现有规范。

## 2026.10.07 节点与订阅展示

- 安装结果与节点页的 URI 恢复完整单行输出，不主动换行、不读取 SSH 窗口尺寸、不限制为 128 字符；不得添加空格或丢失字符，订阅文件仍保持每个 URI 一行。
- 订阅链接顺序固定为订阅面板、节点链接格式（`/raw`）、自适应订阅、Base64 订阅、Clash/Mihomo 订阅、Sing-box 订阅。
- 订阅面板中英文标题为“AGS 订阅中心” / “AGS Subscription Center”，采用 Material 官网亮色配色及 R2Gate 状态 / 订阅 / 开源协议 / GitHub 导航与列表字体。常见桌面和手机窗口应单屏完整显示；协议全文分页。列表列为文件、格式、修改时间、大小/字节、下载；`auto` 显示默认 Base64 文件更新时间，大小为“按客户端”。状态页真实检查订阅入口和页面资源，不将其表述为节点连通性。使用本仓库 GPL v3 协议，保留原文下载。生成 `index.zh.html` / `index.en.html`，默认首页与保存的脚本语言同步，`ags -l` 自动更新已安装面板；配置事务同时备份和恢复所有面板资源。HTML 源修改须用 `python scripts/embed-panel.py` 同步内嵌模板。
