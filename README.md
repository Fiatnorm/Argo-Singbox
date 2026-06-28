# SBA 轻量版

这是一个仅面向固定 Argo Token 隧道的中文安装脚本，只保留：

- VLESS + WS + TLS：`/sba-vl`、`/sba-vl2`
- VMess + WS + TLS：`/sba-vm`
- Trojan + WS + TLS：`/sba-tr`

TLS 由 Cloudflare 边缘终止；VPS 本机的 Nginx 和 sing-box 仅监听回环地址。固定隧道在 Cloudflare Zero Trust 中的 Public Hostname 服务地址应设置为：

```text
http://localhost:3010
```

## 安装

将仓库放到服务器后执行本地脚本：

```bash
chmod +x sba.sh
sudo ./sba.sh
```

安装过程仅要求输入 Argo Token，并允许确认 Argo 域名和 UUID。安装后 `sb` 固定链接到 `/etc/sba/sb.sh`，不会重新下载 GitHub 脚本。

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

## 支持范围

- Debian / Ubuntu
- systemd
- amd64 / arm64
- 固定 Argo Token 隧道

本项目不包含 Reality、临时隧道、Argo Json、Cloudflare API 建隧道、快速安装、英文界面、订阅、ArgoX、其他协议脚本或外部项目安装入口。
