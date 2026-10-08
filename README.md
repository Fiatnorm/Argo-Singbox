# Argo-Singbox v2026.10.08

Argo-Singbox 是单内核项目，`AGS` 是管理命令和终端紧凑显示使用的简称。当前脚本版本 `2026.10.08`。默认使用中文，可通过 `ags -l` 或控制中心的语言设置切换为简体中文，选择保存后持续生效。运行时只安装和管理官方 Sing-box，保留节点、订阅、WARP、长期全局流量统计、诊断、备份恢复和安装更新能力。

## 项目结构

- `argo-singbox.sh`：唯一安装与管理入口。
- `argo-singbox.env.example`：配置格式示例。
- `argo-singbox.sh.sha256`：入口脚本校验值。
- `reference/sba/`：本地只读对照树，不随本仓库发布；2026-09-28 已核验与上游 `fscarmen/sba` `main` 的 `e53b6701f7ac17a20e57eab3db4c0cc3d8a6b80d` 一致。
- `TERMINAL_UI_DESIGN.md`：64 列终端 UI 合同。
- `UPSTREAM_PARITY.md`：Argo-Singbox 与 SBA / ArgoX 共有功能、差异和取舍。
- `AGENTS.md`：工程、验证和发布约束。

原始组合项目工作区及其 `sba/` 参考树不会被本项目自动移动、删除或覆盖。

## 支持范围

- Debian / Ubuntu + systemd，amd64 / arm64。
- 固定 Cloudflare Argo Token。
- Sing-box 官方稳定版 `SagerNet/sing-box` `v1.13.18`。
- VLESS、VMess、Trojan WebSocket。
- WS 节点默认启用带 padding 的 h2mux 多路复用，并在服务器已加载 `brutal` 内核模块且配置开关开启时启用 TCP Brutal。
- 每节点 HTTP/SOCKS5 代理 URL、Cloudflare 官方 WARP SOCKS5 域名与 geosite 分类分流。
- Sing-box `direct` 节点出站支持 IPv4/IPv6；双栈时可在配置中心选择地址族，单栈时自动使用可用出口。
- 原始、Base64、Clash/Mihomo、Sing-box 与 User-Agent 自适应订阅。
- 白名单配置文件导入；默认优选入口为 `polestar.com:443`，省略端口时使用 `443`。
- Clash API + SQLite 的每分钟全局上传/下载长期统计。

Sing-box 客户端订阅只是客户端格式，不是第二个服务端内核。

## 安装与管理

项目发布于 `Fiatnorm/Argo-Singbox`。Debian/Ubuntu 可下载 R2 上的安装脚本并直接启动安装：

```bash
curl -fsSL --retry 3 --connect-timeout 10 -o /tmp/argo-singbox.sh https://r2gate.fiatnorm.pp.ua/argo-singbox.sh && sudo bash /tmp/argo-singbox.sh -i --github-refreshed
```

从完整项目目录安装时，先校验脚本：

```bash
cd /path/to/Argo-Singbox
sha256sum -c argo-singbox.sh.sha256
bash argo-singbox.sh -i
```

也可从配置文件首次安装；脚本只解析受支持字段，不执行配置文件内容：

```bash
cp argo-singbox.env.example /root/argo-singbox.env
bash argo-singbox.sh -i -f /root/argo-singbox.env
```

在线更新从 `Fiatnorm/Argo-Singbox` 的 `main` 分支读取并校验 `argo-singbox.sh`。

安装后的主要路径：

```text
/etc/argo-singbox/argo-singbox.sh
/etc/argo-singbox/bin/sing-box
/etc/argo-singbox/bin/cloudflared
/etc/argo-singbox/config/argo-singbox.env
/etc/argo-singbox/config/nodes.conf
/etc/argo-singbox/config/sing-box.json
/etc/argo-singbox/data/traffic.db
/etc/argo-singbox/data/rule-set/
/etc/argo-singbox/subscriptions/
/etc/nginx/conf.d/argo-singbox.conf
/etc/systemd/system/argo-singbox-core.service
/etc/systemd/system/argo-singbox-tunnel.service
/etc/systemd/system/argo-singbox-traffic.service
/etc/systemd/system/argo-singbox-traffic.timer
/usr/local/bin/ags
/usr/local/bin/AGS
```

管理入口：

```text
ags        控制中心（选择一个动作后退出）
ags -n     节点订阅
ags -a     服务管理
ags -c     配置中心
ags -t     流量统计
ags -x     运行诊断
ags -i     项目安装
ags -f     导入配置
ags -v     组件更新
ags -k     备份恢复
ags -b     系统工具
ags -u     项目卸载
ags -l     语言设置（English / 简体中文）
```

## 节点与订阅

`nodes.conf` 每行格式：

```text
标签|协议|传输路径|本地端口|节点出站
```

配置文件中的协议值固定为 `vless`、`vmess`、`trojan`，终端统一显示为 `VLESS`、`VMess`、`Trojan`。新安装默认各生成一个节点；升级不会向已有节点文件静默插入新节点，其他协议会在配置校验阶段中止。

`ags -n` 按顺序显示订阅面板、节点链接格式、自适应订阅、Base64 订阅、Clash/Mihomo 订阅、Sing-box 订阅；节点链接格式仍使用 `/raw`，只为自适应订阅显示一张 QR。

安装结果与节点页恢复每个 URI 完整单行输出，不主动换行、不读取 SSH 窗口尺寸、不限制为 128 字符；终端可按自身设置自然折行。订阅文件仍保持每个 URI 一行。

订阅中心沿用 R2Gate 的顶部品牌栏、状态 / 订阅 / 开源协议 / GitHub 导航与圆角文件列表；使用 Material 官网亮色配色，页面适配单屏。列表按文件、格式、修改时间、大小/字节、下载排列，`auto` 时间取对应 Base64 默认文件的实际更新时间，大小显示“按客户端”。状态页通过浏览器实时检查五个订阅入口、HTML、SVG、QR 的可访问性及基本内容，不代表代理节点连接测试；访问状态页时检查一次，也可手动重新检查。开源协议页展示本仓库 GPL v3 原文，采用分页阅读并提供原文下载。

生成 `index.zh.html` 和 `index.en.html` 两个版本，`index.html` 按保存的脚本语言选择；`ags -l` 保存语言后自动更新已安装面板。中文标题为“AGS 订阅中心”，英文为“AGS Subscription Center”。`assets/subscription-panel.html` 是 HTML 源文件，修改后运行 `python scripts/embed-panel.py` 同步脚本内嵌内容。用户 SVG、HTML 模板与 GPL 原文都内嵌于安装脚本，单文件安装不需下载额外资产。配置事务备份和恢复两种语言、当前首页、图标、协议文件；页面只使用本地资源。

自适应入口按 User-Agent 匹配常见 Clash/Mihomo、Sing-box 和 URI/Base64 客户端，直接返回本地原子生成的对应订阅；原 `/clash` 与 `/sing-box` 输出格式不变。

节点标签接受当前主流客户端常见的中英文、数字、空格及常用符号，禁止控制字符和字段分隔符 `|`。添加、修改和删除节点前会先验证现有配置；监听端口不得与其他节点、Argo 回源、Clash API 或启用中的 WARP SOCKS5 冲突。添加节点页会先显示当前节点列表；节点配置不再反复要求输入，任一字段无效即终止本次命令，已有配置保持不变。

WS early-data 与 SBA/ArgoX 一致为 `2560`。节点输出不再强制 XUDP 或固定 TLS 指纹，由客户端使用默认值；VMess 安全算法使用 SBA 的 `auto`。

## 配置导入

复制 `argo-singbox.env.example` 后填写需要的字段。首次安装使用 `bash argo-singbox.sh -i -f /path/to/argo-singbox.env`，已安装实例使用 `ags -f /path/to/argo-singbox.env`，也可从 `ags -c` 进入“配置导入”。导入限制为 64 KiB、普通非链接文件与固定字段白名单；未知字段、异常行、无效 URL 或参数会在写入前中止。运行时更新沿用现有快照、配置检查、服务重启和失败回滚事务。

## 命令与终端行为

菜单与输入页统一显示高亮的 `Enter · 默认 | 0 · 退出`。菜单按最安全选项处理 Enter；危险确认 `[y/N]` 的 Enter 默认拒绝。0 在菜单和文本输入中都直接退出脚本，不返回上一级。项目卸载必须输入 `REMOVE`。脚本启动时不执行 `clear`。

首页以 64 列显示系统环境、功能特性与运行状态。运行状态依次显示服务与功能状态、节点概览、Argo 域名/优选入口/回源、VPS IPv4、VPS IPv6、全局流量、运行内存、组件版本。公网 IP 信息来自 GeoJS `https://get.geojs.io/v1/ip/geo.json`，IPv4 与 IPv6 分别通过 `curl -4` 和 `curl -6` 验证；IPv4 检测失败会明确显示 GeoJS 查询失败，IPv6 未确认时显示 None，不以多个“未知”字段冒充结果。GeoJS 的 `country_code`、`asn`、`organization_name`（缺失时使用 `organization`）分别用于国家/地区代码、`AS` 编号和组织名。双栈时配置中心允许选择节点 `direct` 出站使用 IPv4 或 IPv6，默认 IPv4；IPv4 不可用而 IPv6 可用时自动使用 IPv6。该设置控制节点的直连出口，与订阅优选入口无关。运行内存是管理脚本和项目服务进程的 RSS 总和，包含 Sing-box、cloudflared、流量采集、Nginx 与已安装的 WARP；它不是脚本文件大小，也不包含 VPS 上无关进程。项目没有 Node.js 运行组件。正常启用状态使用绿色，警告和提醒使用黄色，错误和异常使用红色；节点概览使用紫色，菜单编号、Enter、0 及项目/组件版本值使用黄色。控制中心使用 `TERMINAL_UI_DESIGN.md` 品牌头部中的六行 ASCII 大字标，最大显示宽度为 64 列。脚本每次运行退出时会在标准输出末尾追加一行空行。WARP 是可选能力，未启用不会计入诊断警告。

控制中心按“常用操作、运行观测、系统维护、项目管理”分组；配置页将 WARP 开关与域名/geosite 规则、TCP Brutal 操作与 h2mux 操作分别分组。终端对象名固定使用 `Argo Tunnel`、`Sing-box Core`、`WARP`、`h2mux`、`TCP Brutal`、`SOCKS5` 与 `Clash API`。结果行统一使用 `✓ / ! / ✗ / •` 表达成功、提醒、错误和过程信息；诊断使用对象名加状态的报告行；完整 URL 与节点 URI 不截断。标准输出与标准错误分别根据对应终端状态控制 ANSI 颜色。

## WARP geosite

WARP 可同时匹配域名和 geosite 分类，例如 `google,openai,geolocation-!cn`；输入也接受 `geosite:google`。域名管理与 geosite 分类分别进入独立子页面，各自提供添加和删除操作。分类规则从官方 `SagerNet/sing-geosite` 的 `rule-set` 分支下载为本地 `.srs` 缓存，Sing-box 配置使用本地二进制 rule-set。规则顺序仍为 `WARP → 节点 HTTP/SOCKS5 → direct`，新增或修改分类必须先通过下载、JSON 生成与 Sing-box 配置检查。

## 流量统计

Sing-box 通过 `experimental.clash_api` 在 `127.0.0.1:18085` 提供本机 REST API。采集器每分钟读取 `/connections` 的 `uploadTotal` 和 `downloadTotal`，按进程启动标识与上次原始计数计算增量，再写入 SQLite。

`argo-singbox-core.service` 停止前会执行一次最终采集；核心重启、PID 变化或原始计数回退时会建立新基线并继续累加。重置操作会清空持久化总量，同时保留当前进程原始计数作为新基线，避免重置前流量再次计入。数据库只保存一组全局累计值和一组当前进程基线，不创建或读取节点明细。

## h2mux 与 TCP Brutal

服务端三个 WS 入站默认启用 h2mux 兼容的多路复用和 padding。Clash/Mihomo 与 Sing-box 订阅会同步生成对应的客户端配置；原始 URI 与 Base64 订阅不写入非标准私有参数。可在 `ags -c` 的“h2mux / TCP Brutal”页面分别启用或停用 TCP Brutal 与 h2mux；停用 h2mux 会同时停用依赖它的 TCP Brutal，但不会卸载 `brutal` 内核模块。

脚本先检查已加载模块，再尝试 `modprobe brutal`。只有模块可用、h2mux 已启用且 TCP Brutal 配置开关开启时，服务端和两类结构化订阅才启用 TCP Brutal。启用 TCP Brutal 会同步启用 h2mux 与 padding；默认上下行带宽均为 1000 Mbps。

同一页面提供 TCP Brutal 安装与更新。执行安装前会验证 Linux、内核不低于 4.9、非 WSL/容器、当前内核存在 `/lib/modules` 且启用 `CONFIG_MODULES`，并按官方安装器规则检查 APT、DKMS 以及当前运行内核精确对应的 `linux-headers-$(uname -r)`。内核头文件未安装时，只有该精确软件包在当前 APT 源中可安装才会继续，不能以其他版本头文件替代。若首次预检、APT 刷新后复检或精确头文件安装任一阶段发现该软件包不可用，Debian 会进入内核升级引导：先说明磁盘空间、当前服务不切换内核、本次不继续安装 Brutal 等影响，再由用户确认是否安装发行版内核与匹配头文件；安装完成后另行确认是否立即重启，并明确 SSH 会中断。默认不安装、默认不重启。重启进入新内核后需重新运行 `ags -c` 安装 TCP Brutal。内核低于 5.8 时提示仅支持 IPv4，低于 4.13 时额外提示 `fq pacing` 要求。预检通过后才下载固定在上游提交 `f11e52d88c7ad2285896de018c2d96d4687f0ab6` 的 [tcp-brutal 官方 DKMS 安装器](https://github.com/apernet/tcp-brutal)，以及官方稳定版 `v1.0.3` DKMS 模块包；两者分别通过固定 SHA256 校验后，使用安装器的 `--local` 模式安装。模块成功加载后，脚本会重新生成服务端及订阅配置并验证服务重启。

## 从旧组合项目迁移

Argo-Singbox 不会自动接管 `/etc/afs`，避免迁移时误停或覆盖现有旧项目。推荐流程：

1. 在旧项目执行 `af -k` 备份 `nodes.conf`。
2. 停止旧项目，确认目标端口和 Nginx 配置不冲突。
3. 安装 Argo-Singbox，重新填写 Token、域名、UUID、优选入口和 WARP 参数。
4. 使用 `ags -k` 恢复节点备份，再执行 `ags -x`。

同一 VPS 若同时运行两个拆分项目，必须为回源端口、统计端口、全部节点端口、Argo 域名和 Nginx server 配置分别避让；默认配置不用于并行安装。

## 验证边界

本地最低验证：

```bash
bash -n argo-singbox.sh
bash tests/tcp-brutal-smoke.sh
bash tests/config-import-smoke.sh
bash tests/generation-smoke.sh
bash tests/traffic-global-smoke.sh
bash tests/installer-migration-smoke.sh
bash tests/ui-smoke.sh
sha256sum -c argo-singbox.sh.sha256
grep -n $'\r' argo-singbox.sh && exit 1 || true
```

本地检查不能替代 VPS 上的 `nginx -t`、Sing-box 配置检查、systemd、Clash API 实时计数、Cloudflare Tunnel 及公网 WS 实测。

## 2026.10.08 界面与节点代理

- 默认中文；中文与英语共享菜单、颜色、危险确认和退出逻辑。语言保存在 `/etc/argo-singbox/config/language`（权限 600）。
- 控制中心使用六行斜体 ASCII 字标，单行标题为 `Argo-Singbox  v2026.10.08 · Argo Tunnel · Sing-box Core`。系统环境单行显示，Kernel 仅显示数字版本，节点概览为紫色；运行状态内以组件版本字段显示 Sing-box / cloudflared，只有版本号为黄色，名称与分隔符为白色。
- 脚本统计保留原联网计数源及单次限时请求，中英文均显示 `Executed 6 times`；不显示“全局累计”。没有确认到 IPv6 时显示 `None`。
- 第五字段支持 `http://user:pass@host:port`、`socks5://user:pass@host:port`，IPv6 主机使用方括号；兼容旧 `host:port:user:pass` 和逐节点 `direct:ipv4` / `direct:ipv6`。凭据继续限于字母、数字及 `._~-`，不支持 URL 编码或省略认证。概览仅显示类型和主机端口。
- 出站优先级为 `WARP → 节点 HTTP/SOCKS5 → direct`。HTTP 使用 Sing-box 的 HTTP CONNECT 出站。

配置生成使用 1.13.18 的 `domain_resolver` 与本地 DNS，不依赖已停用的旧 `domain_strategy` 兼容开关。普通布局 64 列；品牌标题保持单行并位于 64 列布局内。

## 2026.10.08 排版修订

- 默认中文，已显式保存的语言选择继续有效；中文和英文使用同一布局。
- 字标首行之前不额外输出空行。顶部信息标签占 12 个显示列，后跟两个空格，与标题版本号同在第 15 列；其余键值标签占 18 列，后跟两个空格，值起始列为 21。使用 UTF-8 字符码点计算显示宽度，避免 locale 改变中文宽度或误判英文。
- 品牌、功能特性、系统环境、脚本统计各占一行。系统环境示例为 `Debian GNU/Linux 13 · amd64 · Kernel 6.12.101`，不显示 `+deb13-amd64` 构建后缀。
- 执行次数始终为 `Executed N times`，失败为 `Unavailable`，不会人为递增 API 返回的次数。
- 删除运行状态中的节点落地 IP 行；保留配置页的直连地址族功能。组件版本在运行状态下显示为 `Sing-box 1.13.18 · cloudflared 2026.7.3`，只有数字版本为黄色，组件名和分隔符为白色。
- 蓝色分隔线及页面 Enter/0 提示保持 64 列；信息字段不因这条线而截断或换行。
- 内存采用唯一 PID 的 RSS 总和：管理脚本、Nginx master/workers、Sing-box、cloudflared、活跃流量采集及 SQLite 子进程、已安装 WARP。重叠 MainPID/cgroup/后代 PID 只算一次。SQLite 数据库文件不是进程内存；库页已经计入进程 RSS。RSS 可能包含各进程共享页，不能视为去重后的物理内存或 PSS；不可读进程会标记统计不完整。

## 2026.10.08 紧凑布局补充

顶部标题为 `Argo-Singbox  v2026.10.08 · Argo Tunnel · Sing-box Core`。功能特性、系统环境和执行次数的值从第 15 列开始，与标题版本号对齐；运行状态和普通字段从第 21 列开始。系统名称使用 NAME 和 VERSION_ID，省略发行代号；执行次数仍为 API 实际返回的 `Executed N times`。组件版本仅显示 `Sing-box 1.13.18 · cloudflared 2026.7.3`，仅数字为黄色。菜单、Enter/0 提示和 64 列分隔线保持现有规范。
