# Argo-Singbox v2026.08.12

Argo-Singbox 是单内核项目，`AGS` 是管理命令和终端紧凑显示使用的简称。脚本版本按 `YYYY.MM.DD` 日期迭代。运行时只安装和管理官方 Sing-box，保留节点、订阅、WARP、长期全局流量统计、诊断、备份恢复和安装更新能力。

## 项目结构

- `argo-singbox.sh`：唯一安装与管理入口。
- `argo-singbox.env.example`：配置格式示例。
- `argo-singbox.sh.sha256`：入口脚本校验值。
- `reference/sba/`：本地只读对照树，不随本仓库发布；2026-08-10 已核验与上游 `fscarmen/sba` `main` 的 `9388bac7cba21b7ce3d5acd6698db9359f328bf1` 一致。
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
- 每节点 SOCKS5、Cloudflare 官方 WARP SOCKS5 域名与 geosite 分类分流。
- 原始、Base64、Clash/Mihomo、Sing-box 与 User-Agent 自适应订阅。
- 白名单配置文件导入；默认优选入口为 `polestar.com:443`，省略端口时使用 `443`。
- Clash API + SQLite 的每分钟全局上传/下载长期统计。

Sing-box 客户端订阅只是客户端格式，不是第二个服务端内核。

## 安装与管理

项目发布于 `Fiatnorm/Argo-Singbox`。Debian/Ubuntu 可直接下载当前 `main` 脚本并安装：

```bash
curl -fsSL --retry 3 --connect-timeout 10 -o /tmp/argo-singbox.sh https://raw.githubusercontent.com/Fiatnorm/Argo-Singbox/main/argo-singbox.sh && sudo bash /tmp/argo-singbox.sh -i
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
ags -a     服务启停
ags -c     参数配置
ags -t     流量统计
ags -x     运行诊断
ags -i     项目安装
ags -f     导入配置
ags -v     组件更新
ags -k     备份恢复
ags -b     BBR / DD
ags -u     项目卸载
```

## 节点与订阅

`nodes.conf` 每行格式：

```text
标签|协议|传输路径|本地端口|SOCKS5
```

协议固定为 `vless`、`vmess`、`trojan`。新安装默认各生成一个节点；升级不会向已有节点文件静默插入新节点，其他协议会在配置校验阶段中止。

`ags -n` 显示订阅面板、自适应、原始、Base64、Clash/Mihomo 与 Sing-box 链接；只为自适应订阅显示一张 QR。

自适应入口按 User-Agent 匹配常见 Clash/Mihomo、Sing-box 和 URI/Base64 客户端，直接返回本地原子生成的对应订阅；原 `/clash` 与 `/sing-box` 输出格式不变。

节点标签接受当前主流客户端常见的中英文、数字、空格及常用符号，禁止控制字符和字段分隔符 `|`。添加节点页会先显示当前节点列表；节点配置不再反复要求输入，任一字段无效即终止本次命令，已有配置保持不变。

WS early-data 与 SBA/ArgoX 一致为 `2560`。节点输出不再强制 XUDP 或固定 TLS 指纹，由客户端使用默认值；VMess 安全算法使用 SBA 的 `auto`。

## 配置导入

复制 `argo-singbox.env.example` 后填写需要的字段。首次安装使用 `bash argo-singbox.sh -i -f /path/to/argo-singbox.env`，已安装实例使用 `ags -f /path/to/argo-singbox.env`，也可从 `ags -c` 进入“导入配置文件”。导入限制为 64 KiB、普通非链接文件与固定字段白名单；未知字段、异常行、无效 URL 或参数会在写入前中止。运行时更新沿用现有快照、配置检查、服务重启和失败回滚事务。

## 命令与终端行为

脚本遵循标准单动作 Unix CLI：每次执行只选择或指定一个动作，完成后直接退出，不回到当前或上级菜单。所有可取消输入统一提示 `Enter · 默认 | 0 · 取消`。脚本启动时不执行 `clear`，因此不会抹去命令上下文，也不会额外制造整屏重绘。

首页以 64 列显示系统环境、服务状态、VPS IPv4 与英文国家代码/ASN/运营商、全局上传/下载累计量以及当前管理脚本的运行内存。IP 归属合并为一行，上传与下载合并为一行；内核版本隐藏 Debian 构建后缀。状态统一为绿色“已启用”、黄色“未启用”，异常为鲜红色并使用 `原因：...` 说明。WARP 是可选能力，未启用不会计入诊断警告。

## WARP geosite

WARP 可同时匹配域名和 geosite 分类，例如 `google,openai,geolocation-!cn`；输入也接受 `geosite:google`。域名管理与 geosite 分类分别进入独立子页面，各自提供添加和删除操作。分类规则从官方 `SagerNet/sing-geosite` 的 `rule-set` 分支下载为本地 `.srs` 缓存，Sing-box 配置使用本地二进制 rule-set。规则顺序仍为 `WARP → 节点 SOCKS5 → direct`，新增或修改分类必须先通过下载、JSON 生成与 Sing-box 配置检查。

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
