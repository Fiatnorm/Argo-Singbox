# Argo-Singbox v2.7.0

面向固定 Argo Token 隧道的中文轻量安装脚本，提供：

- VLESS + WS + TLS：`/sba-vl`
- VMess + WS + TLS：`/sba-vm`
- Trojan + WS + TLS：`/sba-tr`
- 原始节点、二维码、原始订阅与 Base64 通用订阅

TLS 由 Cloudflare 边缘终止；VPS 本机 Nginx 和 sing-box 仅监听回环地址。固定隧道必须在 Cloudflare Zero Trust 添加 Public Hostname，Service 指向 `http://localhost:3010`。Public Hostname 域名必须由安装者输入，项目不再提供公共默认域名。

## 支持范围

仅支持 Debian/Ubuntu + systemd，以及 amd64/arm64。首次安装自动生成随机 UUID；也可在提示时自行替换。

## 安装

```bash
chmod +x argo-singbox.sh
sudo ./argo-singbox.sh
```

安装时输入 Argo Token、Public Hostname，并以一行 `域名/IP:端口` 的形式输入 Cloudflare 优选入口，例如 `skk.moe:443`。IPv6 使用 `[2001:db8::1]:443`。

核心安装在项目私有目录：

```text
/etc/sba/bin/sing-box
/etc/sba/bin/cloudflared
```

服务使用 `sba-sing-box.service` 和 `sba-cloudflared.service`，不会覆盖系统已有的通用 `sing-box.service` 或 `cloudflared.service`。仅在覆盖现有项目配置时创建一个 `config-previous` 必要备份，不累计时间戳备份，也不为全新安装建立空备份目录；脚本只重建项目管理的文件。

下载具有总超时、重试、GitHub 代理回退和 GitHub Release SHA256 digest 校验；二进制还会执行基本版本检查。sing-box 版本优先采用上游 `force_version`，不可用时回退到 GitHub releases，再失败才使用脚本预设版本。

## 是否需要反复拉取 GitHub

仓库只需在首次部署或需要取得新版安装脚本时拉取一次。安装完成后，脚本会复制到 `/etc/sba/argo-singbox.sh`，并建立本地命令 `/usr/local/bin/asb`。查看节点、修改 Token/优选入口、启停或重启服务、查看状态和卸载都直接使用 VPS 上的本地文件，不会重新拉取本仓库。

以下操作仍会主动访问网络：

- 首次安装或再次执行“安装 / 更新”：查询并下载 sing-box、cloudflared 官方发布物。
- `asb -v`：查询 GitHub Release/`force_version`，有更新并确认后下载核心。
- 健康检查：访问 Cloudflare 公网入口。
- 状态诊断：尝试访问 `api.ipify.org` 获取公网 IP，失败时自动使用本机地址。
- `asb -b`：明确执行第三方的内核升级、BBR 和 DD 系统脚本。

因此，后续管理不需要 `git pull`，但 Argo 隧道本身及核心在线更新显然仍需要 VPS 能访问互联网。

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
9. 备份 /etc/sba (asb -k)
10. 恢复 /etc/sba (asb -l)
11. 第三方 BBR / DD 工具 (asb -b)
12. 卸载 Argo-Singbox (asb -u)
0. 退出
```

## 集中配置与分流

`asb -c` 集中修改 Token、Argo 域名、优选入口、Argo Tunnel 回源端口和全局 UUID，也可以添加、修改或删除 VLESS、VMess、Trojan 的 WS + TLS 节点。修改 Tunnel 回源端口时，节点监听端口从“回源端口 + 1”开始依次顺延；添加节点时默认使用当前最大监听端口的下一个端口。配置保存在 `/etc/sba/nodes.conf`。修改后还必须在 Cloudflare Public Hostname 中把 Service 同步为新的 `http://localhost:端口`。

添加节点时可留空使用直连，也可输入 SOCKS5 出站：

```text
203.0.113.10:1080:proxyuser:proxypass
```

路由按节点的 sing-box inbound tag 匹配，因此同一种协议的不同 WS 路径可以使用不同出口。SOCKS5 地址、端口、用户名和密码只写入权限为 `600` 的项目配置；节点分享链接不包含出站凭据。配置变更会依次执行 sing-box 配置检查、`nginx -t`、服务重启和状态验证，失败时恢复修改前文件。

### 按网址优先使用 WARP

`asb -c` 的 WARP 入口使用 Cloudflare 官方 Linux 客户端的本地 SOCKS5 proxy 模式。启用前需按 [Cloudflare 官方文档](https://developers.cloudflare.com/warp-client/get-started/linux/) 安装 `cloudflare-warp`。输入以逗号分隔的网址或域名，例如：

```text
https://chatgpt.com,api.openai.com,example.com
```

脚本会提取并保存域名、启动 `warp-svc`、注册客户端、切换本地 proxy 模式，再生成优先级明确的 sing-box 路由：

```text
目标域名命中 WARP → WARP
其他流量 → 节点配置的 SOCKS5
没有节点 SOCKS5 → direct
```

WARP 只覆盖匹配的网址，不会替换其他节点的 SOCKS5 配置。`asb -x` 会检查 `warp-svc`、本地代理端口，并通过 WARP 访问第一个目标域名。WARP 不提供匿名保证，也不保证指定国家或地区的落地 IP。

终端输出使用高亮蓝色分区标题、青色序号、白色功能名、淡色命令提示，以及高亮青/绿/黄/红色的信息、成功、警告和错误状态；重定向输出、`TERM=dumb` 或设置 `NO_COLOR=1` 时自动关闭颜色。

## 诊断、备份与恢复

- `asb -x`：检查配置与 Token 同步、三个服务、全部动态监听端口、每条公网 WS 路径、核心版本，并输出最近 30 条项目日志。
- `asb -k [文件.tar.gz]`：备份 `/etc/sba`；省略路径时写入 `/root/asb-backup-时间.tar.gz`。
- `asb -l [文件.tar.gz]`：验证备份中的项目所有权标记和核心文件后恢复 `/etc/sba`，重新生成 Nginx 与 systemd 配置并验证服务；失败自动回滚。

`asb -v` 会先比较本地和远端版本并请求确认，然后下载到临时文件、校验 SHA256/可执行性、执行 `sing-box check`、备份旧核心、原子替换并重启验证。验证失败会自动恢复两个旧核心。

核心更新的备份只用于本次回滚，验证成功后立即删除；失败时保留，便于核对和恢复。

`asb -b` 调用 `ylx2016/Linux-NetSpeed` 外部远程脚本，提供内核升级、BBR 和 DD 系统入口。该工具不属于本项目，执行前会明确提示。

## 节点、订阅和检查

`asb -n` 输出全部原始节点链接、终端二维码、原始订阅、Base64 订阅和兼容的 UUID 订阅地址：

```text
https://你的域名/asb-sub
https://你的域名/asb-sub-base64
https://你的域名/你的UUID
```

原始节点保存在 `/root/argo-singbox_nodes.txt`。安装或配置修改后，会检查三个服务、Nginx 入口及全部节点端口，并对 `/etc/sba/nodes.conf` 中每条路径执行公网 WebSocket 握手。`asb -x` 还会显示核心版本、WARP 状态和最近日志。

如 Cloudflare 返回 Challenge/WAF，需为全部动态代理路径和订阅路径建立适当的 Skip 规则。不要把 Public Hostname 手工解析到 VPS IP；应让流量经过 Argo Tunnel。

## 卸载边界

卸载要求 `/etc/sba/managed` 所有权标记存在。确认所有权后只删除项目管理的核心、配置、服务、Nginx 配置、`asb` 链接和节点文件；如果 `/etc/sba` 中仍有其他文件则保留目录，不会删除 `/usr/local/bin/sing-box`、`/usr/local/bin/cloudflared` 或其他软件的服务。

本项目不包含 Reality、临时隧道、Argo Json、Cloudflare API 建隧道、英文界面或其他协议脚本。
