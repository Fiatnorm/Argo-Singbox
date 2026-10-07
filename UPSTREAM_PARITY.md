# Argo-Singbox 与 SBA 功能核对

核对基线：

- SBA：`reference/sba`，官方 `main` 提交 `e53b6701f7ac17a20e57eab3db4c0cc3d8a6b80d`（2026-09-28 同步）。
- Argo-Singbox：内部测试版本 `v2026.09.30.01`，单一官方 Sing-box 内核。
- 排除项：临时 Argo、JSON/API 等额外隧道凭据获取方式、脚本语言与多语言界面差异。
- 项目硬边界：服务端只保留 VLESS、VMess、Trojan WS；因此 SBA 的 Reality 入站不移植。只支持 Debian/Ubuntu + systemd，不复制 Alpine/OpenRC、CentOS、Arch 的系统适配。

## 功能覆盖矩阵

| SBA 能力 | Argo-Singbox 状态 | 实现与审查结论 |
|---|---|---|
| VLESS / VMess / Trojan WS | 已覆盖并扩展 | SBA 固定生成三节点；本项目默认同样生成三类节点，也允许以 `nodes.conf` 增删改任意数量的这三类 WS 节点。 |
| WS early-data | 已对齐 | 服务端、URI、Clash/Mihomo 和 Sing-box 订阅均使用 `2560` 与 `Sec-WebSocket-Protocol`。 |
| VMess 客户端安全算法 | 已对齐 | URI、Clash 与 Sing-box 客户端配置统一采用 SBA 的 `auto`。 |
| h2mux、padding、TCP Brutal | 已覆盖并强化 | 服务端和结构化订阅同步；Brutal 只有在开关启用且模块真实加载时生效。安装前增加内核、容器、模块、APT、DKMS 和精确头文件预检，并固定安装器与模块包 SHA256。 |
| Argo 固定隧道 | 已覆盖 | 使用 Token + 域名，cloudflared 独立 systemd 服务；临时隧道及额外 Token/JSON/API 获取方式按范围排除。 |
| CDN/优选入口修改 | 已覆盖并扩展 | 一个解析器支持域名、IPv4、方括号 IPv6 与可选端口；省略端口固定为 `443`，所有订阅共用同一入口值。 |
| Nginx WS 回源 | 已覆盖并强化 | 每节点生成 exact location、WebSocket Upgrade 守卫、关闭 buffering 和一小时读写超时；使用系统 `conf.d`，不接管独立 Nginx 主进程。 |
| 节点命名 | 已覆盖并扩展 | 标签支持常见中英文、空格、Emoji 与客户端常用符号，并对 URI、JSON、YAML 分别正确编码。 |
| 节点新增、修改、删除 | 超出 SBA | SBA 没有通用节点 CRUD，只能整体重装或修改固定变量。本项目显示现有节点后单次输入，校验标签、协议、路径、端口和 SOCKS5，再通过快照、配置检查、服务重启与失败回滚应用。 |
| 节点端口安全 | 已强化 | 节点之间不得重复，也不得占用 Argo 回源、Clash API 或启用中的 WARP SOCKS5；修改回源端口时同步顺延节点并再次检查全部保留端口。 |
| 每节点 SOCKS5 | 超出 SBA | 五字段模型将节点入站映射到独立 SOCKS5 出站；路由顺序固定为 `WARP → 节点 SOCKS5 → direct`。 |
| 原始与 Base64 订阅 | 已覆盖 | 原始订阅是标准 VLESS/VMess/Trojan URI；Base64 是原始订阅编码，兼容 SBA 对应的 V2rayN/NekoBox/Shadowrocket 客户端族。 |
| Clash/Mihomo 订阅 | 已覆盖并去除远程依赖 | 本地从 `nodes.conf` 原子生成完整 YAML，不运行时下载 `fscarmen/client_template`。 |
| Sing-box 订阅 | 已覆盖并去除远程依赖 | 本地原子生成 JSON 出站，不把客户端订阅误作第二服务端内核。 |
| User-Agent 自适应订阅 | 已覆盖并扩展 | Nginx 在本地 Base64、Clash/Mihomo、Sing-box 文件间映射；Shadowrocket 等 URI 客户端归入 Base64，不在请求时执行脚本或联网。 |
| QR 与订阅页面 | 已覆盖并强化 | 本地 `qrencode` 生成自适应订阅 SVG；不依赖 SBA 的远程二维码服务或下载未校验的辅助二进制。 |
| WARP/OpenAI 路由 | 已覆盖并扩展 | SBA 自动判断 OpenAI 后选择 direct/WireGuard；本项目由用户明确启用官方 Cloudflare WARP SOCKS5，并支持任意域名与官方 sing-geosite 本地规则，避免共享 WARP 私钥回退。 |
| 配置文件快速安装 | 已覆盖并强化 | 首次安装和运行时均支持白名单配置导入；不 `source` 外部文件，限制普通文件、64 KiB、固定字段和完整校验。 |
| 服务启停与重启 | 已覆盖 | 分别管理 Argo Tunnel、Sing-box Core、流量采集和 Nginx；核心重启范围明确为 Nginx、Sing-box、Argo。 |
| 组件更新 | 已覆盖并强化 | SBA v1.1.8 新增损坏包重试；本项目已有 staging 下载、GitHub SHA256、版本、`with_clash_api` 构建标签、配置预检和失败回滚，证据强于仅 gzip/tar 校验。 |
| WARP 动态注册 | 等价覆盖 | SBA v1.1.8 通过第三方 API 注册 WireGuard 并在失败时使用共享账户；本项目使用 Cloudflare 官方客户端动态注册，失败即停止，不采纳共享密钥降级。 |
| 备份恢复 | 已覆盖并扩展 | 节点归档带清单、严格成员校验，兼容旧项目节点备份；不自动接管或删除 `/etc/afs`。 |
| 流量统计 | 超出 SBA | Clash API 顶层全局计数 + SQLite 长期累计，覆盖每分钟采集、停止前采集、进程重启/计数回退与重置基线。 |
| 诊断、版本、IP、内存 | 已覆盖并扩展 | 64 列状态报告区分错误与提醒，并按对象报告服务、配置、端口、公网 WS、流量与项目进程 RSS。 |
| BBR/系统工具 | 已覆盖 | 保留带默认拒绝确认的 Linux-NetSpeed 入口；第三方工具不被当作项目自身组件。 |
| 卸载 | 已覆盖并强化 | 必须输入 `REMOVE`，项目文件与可选公共包分开确认，不删除不属于项目的目录或服务。 |

## 不机械复刻的 SBA 行为

- Reality 节点与自签证书：违反本项目“三类 WS 服务端协议”合同。
- 临时隧道、JSON、Cloudflare API 建隧道和凭据网站：属于明确排除项。
- Alpine/OpenRC、CentOS、Arch、s390x：超出当前 Debian/Ubuntu + systemd、amd64/arm64 支持面。
- 远程客户端模板、远程二维码服务、共享 WARP 私钥与运行统计上报：本项目已有本地生成或更严格的失败关闭实现，不降低安全边界。
- SBA 的固定端口和固定三节点模型：仅作为默认布局保留；不替换可验证、可回滚的 `nodes.conf` 管理能力。

## 本轮采用的 SBA 证据

- 参考树完整更新到 `e53b6701f7ac17a20e57eab3db4c0cc3d8a6b80d`。
- 复核 v1.1.8 的 Sing-box 下载重试、动态 WARP 注册与 OpenRC 输出变更；前两项已有更严格等价实现，OpenRC 不适用。
- 依据 SBA 固定 `3010 → 3011/3012/3013` 的无冲突布局，补齐可编辑节点模型对 Argo 回源、Clash API 与 WARP SOCKS5 的端口冲突保护。
- 新增/修改/删除节点前先验证现有环境和 `nodes.conf`，避免在异常旧配置上继续变更。
- 修正仅配置 geosite 时诊断仍请求空 URL 的误报；无显式域名时只报告 geosite 规则状态，不伪造连通性结论。

## 2026.10.07

新增默认英语/可持久保存的中文语言设置，参考 SBA 的持久语言选择模式；运行时使用内嵌翻译，不依赖网络翻译。节点五字段继续保留，出站新增 HTTP/SOCKS5 URL；兼容旧 SOCKS5 与逐节点 direct 地址族。
