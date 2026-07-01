# Argo-Singbox v2.3.0

面向固定 Argo Token 隧道的中文轻量安装脚本，提供：

- VLESS + WS + TLS：`/sba-vl`、`/sba-vl2`
- VMess + WS + TLS：`/sba-vm`
- Trojan + WS + TLS：`/sba-tr`
- 原始节点订阅与 Base64 通用订阅

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

服务使用 `sba-sing-box.service` 和 `sba-cloudflared.service`，不会覆盖系统已有的通用 `sing-box.service` 或 `cloudflared.service`。安装会保留配置备份并只重建项目管理的文件，不再删除整个 `/etc/sba`。

下载具有总超时、重试、GitHub 代理回退和 GitHub Release SHA256 digest 校验；二进制还会执行基本版本检查。sing-box 版本优先采用上游 `force_version`，不可用时回退到 GitHub releases，再失败才使用脚本预设版本。

## 是否需要反复拉取 GitHub

仓库只需在首次部署或需要取得新版安装脚本时拉取一次。安装完成后，脚本会复制到 `/etc/sba/argo-singbox.sh`，并建立本地命令 `/usr/local/bin/asb`。查看节点、修改 Token/优选入口、启停或重启服务、查看状态和卸载都直接使用 VPS 上的本地文件，不会重新拉取本仓库。

以下操作仍会主动访问网络：

- 首次安装或再次执行“安装 / 更新”：查询并下载 sing-box、cloudflared 官方发布物。
- `asb -v`：查询 GitHub Release/`force_version`，有更新并确认后下载核心。
- 健康检查：访问 Cloudflare 公网入口。
- 状态诊断：尝试访问 `api.ipify.org` 获取公网 IP，失败时自动使用本机地址。
- `asb -b`：明确执行第三方远程 BBR 脚本。

因此，后续管理不需要 `git pull`，但 Argo 隧道本身及核心在线更新显然仍需要 VPS 能访问互联网。

## 菜单

```text
1. 查看节点信息 (asb -n)
2. 开启/关闭 Argo (asb -a)
3. 开启/关闭 Sing-box (asb -s)
4. 更换 Argo 隧道 Token (asb -t)
5. 更换优选域名、IP 或端口 (asb -d)
6. 检查并更新两个核心 (asb -v)
7. 卸载 (asb -u)
8. 安装 / 更新 Argo-Singbox
9. 查看简洁诊断
10. 重启服务
0. 退出
```

`asb -v` 会先比较本地和远端版本并请求确认，然后下载到临时文件、校验 SHA256/可执行性、执行 `sing-box check`、备份旧核心、原子替换并重启验证。验证失败会自动恢复两个旧核心。

BBR 不再出现在主菜单。兼容参数 `asb -b` 仍可使用，但会明确提示它将执行本项目不维护的 `ylx2016/Linux-NetSpeed` 外部远程脚本。

## 节点、订阅和检查

`asb -n` 输出四条原始节点链接、各节点终端二维码及两个订阅地址：

```text
https://你的域名/sba-sub
https://你的域名/sba-sub-base64
```

原始节点仍保存在 `/root/sba_nodes.txt`。安装、修改 Token 或优选入口后，会检查三个服务、五个本地端口，并分别对 `/sba-vl`、`/sba-vl2`、`/sba-vm`、`/sba-tr` 执行公网 WebSocket 握手。`asb status` 额外显示公网 IP、核心版本、内存、systemd 健康状态、端口列表和最近错误。

如 Cloudflare 返回 Challenge/WAF，需为四个代理路径和两个订阅路径建立适当的 Skip 规则。不要把 Public Hostname 手工解析到 VPS IP；应让流量经过 Argo Tunnel。

## 卸载边界

卸载要求 `/etc/sba/managed` 所有权标记存在，只删除项目私有核心、项目服务、项目 Nginx 配置、`asb` 链接及节点文件，不会删除 `/usr/local/bin/sing-box`、`/usr/local/bin/cloudflared` 或其他软件的服务。

本项目不包含 Reality、临时隧道、Argo Json、Cloudflare API 建隧道、英文界面或其他协议脚本。
