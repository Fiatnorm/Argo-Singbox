# SBA 轻量版

这是一个仅面向固定 Argo Token 隧道的中文安装脚本，只保留：

- VLESS + WS + TLS：`/sba-vl`、`/sba-vl2`
- VMess + WS + TLS：`/sba-vm`
- Trojan + WS + TLS：`/sba-tr`

TLS 由 Cloudflare 边缘终止；VPS 本机的 Nginx 和 sing-box 仅监听回环地址。脚本保留了上游 SBA 的 WebSocket Early Data 配置（`ed=2560`）。

固定隧道必须在 Cloudflare Zero Trust 中添加 Public Hostname：

```text
Hostname: sb.fiatnorm.us.kg
Service:  http://localhost:3010
```

应让 Zero Trust 自动创建并代理该 Hostname 的 DNS 记录。不要把 Hostname 手工解析到 VPS IP，否则客户端不会经过 Argo Tunnel。

## 安装

将仓库放到服务器后执行本地脚本：

```bash
chmod +x sba.sh
sudo ./sba.sh
```

安装过程要求输入 Argo Token，并允许确认：

- Argo Public Hostname
- UUID
- Cloudflare 优选域名/IP

连接逻辑与上游 SBA 一致：节点连接 `SERVER:443`，WebSocket Host 和 TLS SNI 使用 `ARGO_DOMAIN`。默认优选域名为上游列表首项 `skk.moe`。如填写其他优选 IP/域名，它必须能够以 Argo 域名作为 SNI 完成 TLS 握手；不能填写普通 VPS IP。

cloudflared 启动后，脚本会从 Token 下发的 ingress 配置读取实际 Public Hostname。如果它与手工输入不一致，将自动以 Token 中的真实域名重写节点，避免 Host/SNI 指向错误域名。

## Cloudflare 安全规则

代理 WebSocket 路径不能被 Cloudflare Managed Challenge、JS Challenge 或 Bot Fight Mode 拦截。若检查结果包含 `CF-MITIGATED: challenge`，请在 Cloudflare 为以下路径建立 Skip 规则：

```text
/sba-vl
/sba-vl2
/sba-vm
/sba-tr
```

规则表达式示例：

```text
(http.host eq "sb.fiatnorm.pp.ua" and starts_with(http.request.uri.path, "/sba-"))
```

对该规则跳过 Managed Rules、Browser Integrity Check、Security Level 和其他 Challenge 规则；如果账号启用了无法被 Skip 规则绕过的 Bot Fight Mode，需要关闭它。节点客户端无法像浏览器一样完成人机挑战。

安装后 `sb` 固定链接到 `/etc/sba/sb.sh`，不会重新下载 GitHub 脚本。安装器会检查 Nginx、sing-box、cloudflared、本地监听端口和公网 WebSocket 握手；检查不通过时不会再提示“核心链路正常”。

## 菜单

```text
1. 安装 / 更新 SBA
2. 修改 Argo Token
3. 查看运行状态
4. 查看节点文件
5. 重启服务
6. 卸载 SBA
0. 退出
```

## 输出和检查

节点固定写入 `/root/sba_nodes.txt`，不创建订阅链接、订阅页面或订阅转换文件。

```bash
systemctl status sing-box
systemctl status cloudflared
ss -tulnp
cat /root/sba_nodes.txt
```

进一步诊断：

```bash
journalctl -u sing-box -n 100 --no-pager
journalctl -u cloudflared -n 100 --no-pager
curl -vk https://sb.fiatnorm.us.kg/
```

## 支持范围

- Debian / Ubuntu
- systemd
- amd64 / arm64
- 固定 Argo Token 隧道

本项目不包含 Reality、临时隧道、Argo Json、Cloudflare API 建隧道、快速安装、英文界面、订阅、ArgoX、其他协议脚本或外部项目安装入口。
