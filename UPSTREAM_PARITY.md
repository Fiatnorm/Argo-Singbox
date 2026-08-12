# Argo-Singbox 与 SBA / ArgoX 共有功能核对

核对基线：

- SBA：`reference/sba`，提交 `9388bac7cba21b7ce3d5acd6698db9359f328bf1`
- ArgoX：`E:/Code/NodeJS/Argo-Xray/reference/ArgoX`，提交 `7e5207660207639e00b22a8b3fdbd0cccda1ab14`
- Argo-Singbox：单内核 Sing-box，仅比较 VLESS / VMess / Trojan WS、Argo、Nginx、订阅、WARP、h2mux / TCP Brutal 与管理流程；Reality、XHTTP、Hysteria2、Shadowsocks、Xray、临时隧道和 Cloudflare API 建隧道不属于本项目边界。

## 结论表

| 共有功能 | SBA / ArgoX | Argo-Singbox v2026.08.12 的选择 | 代码逻辑差异 |
|---|---|---|---|
| 三类 WS 入站 | 固定生成 VLESS、VMess、Trojan；WS early-data 为 2560 | 对齐 early-data，节点数量仍由 `nodes.conf` 决定 | 一个五字段节点模型同时生成 Sing-box inbound、Nginx exact location 和全部订阅，避免三份列表漂移 |
| 节点客户端参数 | SBA 的 VMess 为 `auto`，ArgoX 为 `none`；不同输出会额外写指纹或 XUDP | VMess 采用 SBA `auto`；不强制 XUDP 和 TLS 指纹，交给客户端默认 | 服务端 WS early-data 仍写 `max_early_data=2560`，URI 使用 `?ed=2560`；结构化订阅同步写 early-data header |
| 优选入口 | ArgoX 允许省略端口并默认 443；部分旧输出仍硬编码 443 | 采用统一解析器，域名、IPv4、方括号 IPv6 均可省略端口 | 所有 URI、YAML、JSON 和公网检测只读取同一组 `SERVER` / `SERVER_PORT`，不在生成器内另写 443 |
| Nginx WS 反代 | SBA 使用项目自带完整 Nginx 配置；ArgoX 按所选协议拼接 location | 保留系统 `conf.d` 集成和逐路径 exact match | 非 WebSocket 请求返回 404；保留 Upgrade、1 小时读写超时、关闭 buffering；不公开无 UUID 的订阅别名 |
| Argo Tunnel | 两个参考项目支持 Token、JSON、API 或临时隧道 | 固定 Token 隧道，服务名与目录均为 Argo-Singbox 专属 | systemd 独立管理 cloudflared；安装后从当前服务日志核对实际 hostname，但固定隧道没有日志时不篡改输入 |
| 原始与 Base64 订阅 | 针对多类客户端生成多份链接 | 保留稳定的 raw 与 Base64 输出 | raw 是三类标准 URI；Base64 只编码 raw，不混入 h2mux/TCP Brutal 私有字段 |
| Clash / Sing-box 订阅 | 下载 fscarmen 模板并直接替换占位符 | 保留项目内建的结构化订阅，不提供远程完整模板 | Clash 与 Sing-box 均从同一 `nodes.conf` 原子生成；原 `/clash`、`/sing-box` 语义不变 |
| User-Agent 自适应 | 按客户端 UA 返回 Shadowrocket、V2rayN、Clash 或 Sing-box 格式 | 扩展为常见 URI/Base64、Clash/Mihomo 与 Sing-box 客户端族 | Nginx `map` 只选择已经原子生成的本地文件，不在请求时执行脚本或访问远端 |
| 配置文件安装 | SBA 与 ArgoX 的 `-f` 直接执行 `. $VARIABLE_FILE` | 提供首次安装与运行时导入，但不执行文件 | 仅接受 64 KiB 内普通非链接文件、`KEY=value` 和固定字段白名单；完整验证后进入现有事务回滚 |
| WARP / geosite | SBA 为 OpenAI 使用远程 `geosite-openai`；ArgoX/Xray 使用 `geosite:` 路由 | 支持任意合法分类和普通域名，规则缓存为本地 `.srs` | 先下载官方 `SagerNet/sing-geosite` 二进制规则，再生成本地 rule-set；顺序固定为 WARP、节点 SOCKS5、direct |
| h2mux / TCP Brutal | 参考项目在生成配置时按模块状态写入，安装检查较少 | 保留对齐的 h2mux/padding/Brutal 字段，强化显式开关和预检 | h2mux 停用会同步停用 Brutal；只有配置开启且模块实际可用才启用；DKMS 安装器和模块包分别固定版本与 SHA256 |
| 安装和更新 | 参考项目覆盖更多发行版并偏向原地下载替换 | 仅支持 Debian/Ubuntu + systemd，保持官方稳定 Sing-box | 二进制先下载到 staging，校验版本、构建标签和 SHA256，再替换；配置更新用快照、语法检查、服务健康检查和失败回滚 |
| 状态与诊断 | 显示进程、版本、IP、WARP 等状态 | 合并显示 VPS IP 归属、总流量、运行内存，并保留节点端口、Nginx、WS、服务与统计检查 | WARP 未启用仅标为可选状态，不计警告；本地静态检查、公网 WS 探测和实时服务证据分开报告 |

## Argo-Singbox 保留而不向参考实现回退的部分

- `nodes.conf` 是节点唯一事实源，支持任意数量的三类 WS 节点以及每节点 SOCKS5；参考脚本的固定节点数组不替换这一模型。
- Nginx 使用精确 location、WebSocket Upgrade 守卫、关闭 buffering 和长连接超时；不复制参考脚本中较宽的匹配或独立 Nginx 主进程管理。
- WARP 路由固定为 `WARP → 节点 SOCKS5 → direct`，不会采用参考脚本的自动解锁判定改变用户配置。
- Clash API 全局计数、SQLite 长期累计、停止前采集、重启/回退基线识别是 Argo-Singbox 独有功能，不因对齐节点生成而删减。
- `/etc/afs` 不自动接管；单内核项目也不加入 ArgoX 的 Xray 协议面或 SBA 的 Reality/临时隧道面。

## 已修正的明确缺陷

- 删除不带 UUID 的 `/ags-sub` 与 `/ags-sub-base64` Nginx 入口，订阅只通过 UUID 路径提供。
- 将 WARP 域名与 geosite 操作分别收进结构一致的管理子页面。
- 删除重复定义且永远不会执行的旧 `control_panel()`，保留当前 Argo-Singbox 64 列 UI 实现。
- 消除节点生成器内的固定 443；所有输出统一消费已验证的优选端口。
