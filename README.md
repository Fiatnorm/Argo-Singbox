# Argo-Singbox v2.10.1

面向固定 Argo Token 隧道的中文轻量安装脚本，提供：

- VLESS + WS + TLS：`/argo-vl`
- VMess + WS + TLS：`/argo-vm`
- Trojan + WS + TLS：`/argo-tr`
- 原始节点、二维码、原始订阅与 Base64 通用订阅

TLS 由 Cloudflare 边缘终止；VPS 本机 Nginx 和 sing-box 仅监听回环地址。固定隧道必须在 Cloudflare Zero Trust 添加 Public Hostname，Service 指向 `http://localhost:3010`。Public Hostname 域名必须由安装者输入，项目不再提供公共默认域名。

## 支持范围

仅支持 Debian/Ubuntu + systemd，以及 amd64/arm64。首次安装自动生成随机 UUID；也可在提示时自行替换。

## 安装

使用 `curl` 一键下载并安装：

```bash
curl -fL --retry 3 --connect-timeout 10 https://raw.githubusercontent.com/Fiatnorm/Argo-Singbox/main/argo-singbox.sh -o argo-singbox.sh && chmod +x argo-singbox.sh && sudo ./argo-singbox.sh -i
```

如果当前已经是 `root` 用户：

```bash
curl -fL --retry 3 --connect-timeout 10 https://raw.githubusercontent.com/Fiatnorm/Argo-Singbox/main/argo-singbox.sh -o argo-singbox.sh && chmod +x argo-singbox.sh && ./argo-singbox.sh -i
```

也可以在已经下载或克隆仓库后运行：

```bash
chmod +x argo-singbox.sh
sudo ./argo-singbox.sh -i
```

安装时输入 Argo Token、Public Hostname，并以一行 `域名/IP:端口` 的形式输入 Cloudflare 优选入口，例如 `skk.moe:443`。IPv6 使用 `[2001:db8::1]:443`。

核心安装在项目私有目录：

```text
/etc/asb/bin/sing-box
/etc/asb/bin/cloudflared
/etc/asb/nodes.txt
/etc/asb/subscription.*
/etc/asb/backup/
```

项目核心、配置、节点和订阅数据统一保存在 `/etc/asb/`。只有 systemd unit、Nginx 站点配置和 `/usr/local/bin/asb` 命令入口按 Linux 系统约定保存在对应系统目录。服务使用 `asb-sing-box.service` 和 `asb-cloudflared.service`，不会覆盖系统已有的通用 `sing-box.service` 或 `cloudflared.service`。

从旧版升级时，脚本仅在 `/etc/sba/managed` 所有权标记有效且 `/etc/asb` 不存在时，将旧目录迁移为 `/etc/asb`、把 `sba.env` 改名为 `asb.env`，并临时保留指向新目录的兼容链接；新服务验证通过后才移除属于本项目的旧 `sba-*` 服务和兼容链接，失败则尝试恢复旧服务。两个真实目录同时存在或旧目录没有所有权标记时会停止并要求人工核对。

迁移会先停止旧服务并等待节点端口释放，再启动新服务；若新服务启动失败，会先停用新服务再恢复旧服务，避免两套 sing-box 同时抢占节点端口。重新执行 v2.8.2 安装可修复旧版迁移失败后形成的新旧服务端口冲突。

v2.8.2 将端口释放检查扩展到每次安装和更新：停止当前 `asb-sing-box`，并识别属于本项目的 `sba-sing-box`、`sba-singbox` 或 `sing-box` 历史服务；项目目录中的遗留 sing-box 进程也会被停止。若端口由未知第三方进程占用，脚本只输出 PID/进程信息并停止安装，不会强制终止第三方服务。

v2.8.3 在用户启用 WARP 且系统缺少 `warp-cli` 时，可自动配置 Cloudflare 官方 APT 软件源并安装客户端。

v2.8.4 修正 WARP 注册检测：读取现有注册时自动接受使用条款；若客户端报告残留的无效旧注册，会在用户确认后删除并重新注册。

v2.9.0 增加按客户端区分的订阅文件和自动适配入口，覆盖 V2rayN/NekoBox、Clash/Mihomo、sing-box 与 Shadowrocket；保留逐行明文节点协议文件。节点修改现在可以直接修改标签、协议、WS 路径、监听端口和节点 SOCKS5。WARP 菜单支持单独添加、删除或整体修改目标域名。

v2.9.1 修复从交互菜单卸载后再次进入面板的问题。卸载会清理项目核心、配置、订阅、备份、服务和命令入口，并分别询问是否额外卸载 Nginx、Cloudflare WARP 及通用系统工具。

v2.10.0 首次安装固定使用 sing-box `1.13.0-rc.4`，cloudflared 与原版 SBA 一样下载 latest；固定 Token 日志未输出 hostname 时不再误报，公网 WS 探测超时也不再阻断安装。新增 UUID 文件索引、可输入备份文件夹、WARP 添加前展示已有域名，并调整节点表格和终端输出间距。

v2.10.1 修复 UUID 配置索引的 Nginx 500 错误；节点文件迁入 `/etc/asb/nodes.txt`；备份和恢复默认使用 `/etc/asb/backup/`；Argo/cloudflared 与 Sing-box 核心改为分别询问是否更新；运行检查、完成信息和明文节点之间增加分区空行。

下载具有总超时、重试、GitHub 代理回退和 GitHub Release SHA256 digest 校验；二进制还会执行基本版本检查。sing-box 版本优先采用上游 `force_version`，不可用时回退到 GitHub releases，再失败才使用脚本预设版本。

首次安装使用经过项目确认的 sing-box `1.13.0-rc.4`，避免安装时因远端版本变化产生不一致；cloudflared 首次安装按原版 SBA 逻辑使用 GitHub latest。后续执行 `asb -v` 时，sing-box 仍按 `force_version`、GitHub releases、预设版本的顺序查询更新。

## 是否需要反复拉取 GitHub

仓库只需在首次部署或需要取得新版安装脚本时拉取一次。安装完成后，脚本会复制到 `/etc/asb/argo-singbox.sh`，并建立本地命令 `/usr/local/bin/asb`。查看节点、修改 Token/优选入口、启停或重启服务、查看状态和卸载都直接使用 VPS 上的本地文件，不会重新拉取本仓库。

以下操作仍会主动访问网络：

- 首次安装或再次执行“安装 / 更新”：查询并下载 sing-box、cloudflared 官方发布物。
- `asb -v`：查询 GitHub Release/`force_version`，有更新并确认后下载核心。
- 健康检查：访问 Cloudflare 公网入口。
- 状态诊断：尝试访问 `api.ipify.org` 获取公网 IP，失败时自动使用本机地址。
- `asb -b`：明确执行第三方的内核升级、BBR 和 DD 系统脚本。

因此，后续管理不需要 `git pull`，但 Argo 隧道本身及核心在线更新显然仍需要 VPS 能访问互联网。

## 完整运行指令

首次从仓库运行：

```bash
cd Argo-Singbox
chmod +x argo-singbox.sh
sudo ./argo-singbox.sh
```

直接执行安装或更新：

```bash
sudo ./argo-singbox.sh -i
```

安装完成后统一使用 VPS 本地命令 `asb`，不需要进入仓库目录：

| 指令 | 功能 |
|---|---|
| `sudo asb` | 打开完整中文管理面板 |
| `sudo asb -i` | 安装或更新脚本、配置和两个私有核心 |
| `sudo asb -n` | 显示全部节点、二维码及所有订阅地址 |
| `sudo asb -a` | 开启或关闭 Argo/cloudflared 服务 |
| `sudo asb -s` | 开启或关闭 sing-box 服务 |
| `sudo asb -c` | 修改 Token、域名、优选入口、端口、UUID、节点、SOCKS5 和 WARP 域名 |
| `sudo asb -r` | 重启 Nginx、sing-box 和 Argo 服务 |
| `sudo asb -x` | 执行完整诊断、WS 检查并显示最近日志 |
| `sudo asb -v` | 比较版本并更新 Argo/cloudflared 与 sing-box 核心 |
| `sudo asb -k [文件夹或文件.tar.gz]` | 备份到指定文件夹或完整归档路径 |
| `sudo asb -k /etc/asb/backup/my-asb.tar.gz` | 备份到指定文件 |
| `sudo asb -l /etc/asb/backup/my-asb.tar.gz` | 从指定备份恢复并验证服务 |
| `sudo asb -b` | 启动第三方 Linux-NetSpeed BBR/DD 工具 |
| `sudo asb -u` | 彻底卸载本项目，并选择是否卸载共享依赖 |

所有操作都要求 root 权限。也可以在仓库中把 `asb` 替换为 `./argo-singbox.sh` 执行相同参数，但日常管理应使用安装到 `/etc/asb/argo-singbox.sh` 的本地 `asb` 命令。

不支持组合参数，也没有后台静默卸载参数。`-u` 会要求确认，避免误删正在使用的 Nginx、WARP 或通用系统工具。

## 菜单

```text
1. 查看节点信息 (asb -n)
2. 开启/关闭 Argo (asb -a)
3. 开启/关闭 Sing-box (asb -s)
4. 集中配置 (asb -c)
5. 重启全部服务 (asb -r)
6. 完整诊断 (asb -x)
7. 安装 / 更新 Argo-Singbox (asb -i)
8. 更新 Argo / Sing-box 核心 (asb -v)
9. 备份 /etc/asb (asb -k)
10. 恢复 /etc/asb (asb -l)
11. 第三方 BBR / DD 工具 (asb -b)
12. 卸载 Argo-Singbox (asb -u)
0. 退出
```

## 集中配置与分流

`asb -c` 集中修改 Token、Argo 域名、优选入口、Argo Tunnel 回源端口和全局 UUID，也可以添加、修改或删除 VLESS、VMess、Trojan 的 WS + TLS 节点。修改 Tunnel 回源端口时，节点监听端口从“回源端口 + 1”开始依次顺延；添加节点时默认使用当前最大监听端口的下一个端口。配置保存在 `/etc/asb/nodes.conf`。修改后还必须在 Cloudflare Public Hostname 中把 Service 同步为新的 `http://localhost:端口`。

添加节点时可留空使用直连，也可输入 SOCKS5 出站：

```text
203.0.113.10:1080:proxyuser:proxypass
```

路由按节点的 sing-box inbound tag 匹配，因此同一种协议的不同 WS 路径可以使用不同出口。SOCKS5 地址、端口、用户名和密码只写入权限为 `600` 的项目配置；节点分享链接不包含出站凭据。配置变更会依次执行 sing-box 配置检查、`nginx -t`、服务重启和状态验证，失败时恢复修改前文件。

### 按网址优先使用 WARP

`asb -c` 的 WARP 入口使用 Cloudflare 官方 Linux 客户端的本地 SOCKS5 proxy 模式。菜单可启用或整体修改配置，也可单独添加、删除目标域名；删除最后一个域名时必须明确停用 WARP，避免生成空规则。启用时若系统尚未安装 `warp-cli`，脚本会征得确认后自动配置 Cloudflare 官方 APT 软件源，校验软件源签名密钥，并安装 `cloudflare-warp`。软件源及系统支持范围见 [Cloudflare 官方 Linux 安装说明](https://developers.cloudflare.com/warp-client/get-started/linux/)。输入以逗号分隔的网址或域名，例如：

```text
https://chatgpt.com,api.openai.com,example.com
```

脚本会提取并保存域名、启动 `warp-svc`、注册客户端、切换本地 proxy 模式，再生成优先级明确的 sing-box 路由：

代理端口提示只能输入数字或直接回车采用默认值；目标网址应在下一条提示中输入。若客户端存在无法读取的旧注册，脚本会先询问是否删除并重新注册，不会静默覆盖现有注册。

```text
目标域名命中 WARP → WARP
其他流量 → 节点配置的 SOCKS5
没有节点 SOCKS5 → direct
```

WARP 只覆盖匹配的网址，不会替换其他节点的 SOCKS5 配置。`asb -x` 会检查 `warp-svc`、本地代理端口，并通过 WARP 访问第一个目标域名。WARP 不提供匿名保证，也不保证指定国家或地区的落地 IP。

终端输出采用克制的青色导航体系：青色用于分区标题、菜单序号和输入提示，正文保持终端默认色，绿色、黄色和红色仅标记成功、警告和错误符号，辅助命令使用淡色显示。分区之间固定保留一个空行；重定向输出、`TERM=dumb` 或设置 `NO_COLOR=1` 时自动关闭颜色。

## 诊断、备份与恢复

- `asb -x`：检查配置与 Token 同步、三个服务、全部动态监听端口、每条公网 WS 路径、核心版本，并输出最近 30 条项目日志。
- `asb -k [文件夹或文件.tar.gz]`：备份 `/etc/asb`，默认保存到 `/etc/asb/backup/asb-backup-时间.tar.gz`。归档会排除 `backup/` 自身，避免递归包含历史备份；也可指定其他绝对路径。
- `asb -l [文件夹或文件.tar.gz]`：默认从 `/etc/asb/backup/` 选择最新归档，也可指定目录或完整文件。验证所有权标记和核心文件后恢复 `/etc/asb`，重新生成 Nginx 与 systemd 配置并验证服务；失败自动回滚。

`asb -v` 会分别显示 Argo/cloudflared 与 Sing-box 的本地、目标版本，并分别询问是否更新。只下载、备份、替换和重启用户确认更新的核心；下载文件会校验 SHA256/可执行性，Sing-box 还会执行配置检查。验证失败时只回滚本次选择的核心。

核心更新的备份只用于本次回滚，验证成功后立即删除；失败时保留，便于核对和恢复。

`asb -b` 调用 `ylx2016/Linux-NetSpeed` 外部远程脚本，提供内核升级、BBR 和 DD 系统入口。该工具不属于本项目，执行前会明确提示。

## 节点、订阅和检查

`asb -n` 输出配置文件索引、全部原始节点链接和终端二维码。浏览器访问 `https://你的域名/你的UUID/` 可进入文件索引，再打开不同客户端配置：

```text
https://你的域名/你的UUID/auto
https://你的域名/你的UUID/raw
https://你的域名/你的UUID/base64
https://你的域名/你的UUID/clash
https://你的域名/你的UUID/proxies
https://你的域名/你的UUID/sing-box
https://你的域名/你的UUID/shadowrocket
```

`/你的UUID` 会跳转到文件索引；索引 HTML 由 Nginx 直接返回，避免目录 URL 使用文件 `alias` 导致 500。`/auto` 根据 User-Agent 为 Clash/Mihomo、sing-box 和 Shadowrocket 返回对应格式，其他客户端返回 Base64 通用订阅。`/raw` 以及 `/etc/asb/nodes.txt` 保留逐行明文 `vless://`、`vmess://`、`trojan://` 节点协议。旧的 `/asb-sub` 与 `/asb-sub-base64` 入口继续可用。

二维码只为“自动适配订阅地址”和每条可直接导入的明文节点生成。Clash、sing-box 等配置文件地址不单独生成二维码，避免用户把客户端不支持的文件 URL 当成通用订阅扫描。

默认标签使用接近原版 SBA 的 `Argo-Vl`、`Argo-Vm`、`Argo-Tr` 后缀形式。`asb -c` 修改节点时可直接修改标签和协议；标签同时作为 sing-box inbound tag 和各客户端显示名称。

如 Cloudflare 返回 Challenge/WAF，需为全部动态代理路径和订阅路径建立适当的 Skip 规则。不要把 Public Hostname 手工解析到 VPS IP；应让流量经过 Argo Tunnel。

固定 Token 模式下 cloudflared 日志不保证包含 Public Hostname，因此脚本无法从日志读取 hostname 时会保留用户输入域名，不再显示失败提醒。公网 WS 探测经过优选入口，单次超时只显示非阻断提示；明确的 HTTP 错误、Cloudflare Challenge 或本地服务/端口异常仍会使健康检查失败。最终连通性应以客户端实测为准。

## 卸载边界

`sudo asb -u` 要求 `/etc/asb/managed` 所有权标记存在，并再次确认卸载。确认后固定删除：

- `/etc/asb` 中的项目核心、配置、订阅和项目备份；
- `asb-sing-box.service`、`asb-cloudflared.service` 以及确认属于本项目的旧服务；
- `/etc/nginx/conf.d/argo-singbox.conf`、项目旧 Nginx 配置、`/usr/local/bin/asb`；
- `/etc/asb/nodes.txt`、旧版 `/root` 节点文件、项目迁移链接和兼容节点文件。

私有 `/etc/asb/bin/cloudflared`（Argo）和 `/etc/asb/bin/sing-box` 一定随项目删除。卸载完成后脚本立即退出，不会重新显示管理面板。

Nginx、Cloudflare WARP 和 `curl/ca-certificates/openssl/tar/qrencode/gnupg` 可能被其他网站或脚本共用，因此分别询问且默认不卸载；明确输入 `y` 后使用 APT purge。选择卸载 WARP 时还会断开连接、删除注册、停止 `warp-svc`，并删除本脚本配置的 Cloudflare APT 软件源和密钥。选择保留 Nginx 时只删除本项目站点配置并重启 Nginx。

只有确认 `/etc/asb/managed` 项目所有权标记后，脚本才递归删除整个 `/etc/asb`，因此项目备份、旧版迁移文件或历史订阅不会残留。请勿把个人文件放入该项目私有目录。脚本不会删除 `/usr/local/bin/sing-box`、`/usr/local/bin/cloudflared` 或非本项目 systemd 服务。

本项目不包含 Reality、临时隧道、Argo Json、Cloudflare API 建隧道、英文界面或其他协议脚本。
