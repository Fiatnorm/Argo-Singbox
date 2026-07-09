    ___                     _____ _             __
   /   |  _________ _____  / ___/(_)___  ____ _/ /_  ____  _  __
  / /| | / ___/ __ `/ __ \ \__ \/ / __ \/ __ `/ __ \/ __ \| |/_/
 / ___ |/ /  / /_/ / /_/ /___/ / / / / / /_/ / /_/ / /_/ />  <
/_/  |_/_/   \__, /\____//____/_/_/ /_/\__, /_.___/\____/_/|_|
            /____/                    /____/

Argo-Singbox v2.11.4  Argo Tunnel  ·  Sing-box Core  ·  WSS Proxy
系统环境  Debian GNU/Linux 13 (trixie) · amd64 · IP 173.231.53.138 (这上下两行需要对齐)
------------------------------------------------------------------
▸ 运行概览（颜色区别于下面的运行配置）
Argo 服务      运行中
Sing-box 服务  运行中
Argo 域名      greencloud-asb.fiatnorm.pp.ua
优选入口       142.248.136.72:443
Argo 回源      127.0.0.1:3010
组件版本       Argo-Singbox v2.11.4 · Sing-box 1.13.0-rc.4 · Cloudflared 2026.7.0
WARP 分流      未启用 （这一列需要对齐）
------------------------------------------------------------------

◆ Argo-Singbox · 控制中心
------------------------------------------------------------------
▸ 日常管理
   1  查看节点信息                     [asb -n]
   2  开启/关闭 Argo                   [asb -a]
   3  开启/关闭 Sing-box               [asb -s]
   4  集中配置                         [asb -c]
   5  重启全部服务                     [asb -r]
   6  完整诊断                         [asb -x]

▸ 维护工具
   7  安装 / 更新 Argo-Singbox         [asb -i]
   8  更新 Argo / Sing-box 核心        [asb -v]
   9  备份 /etc/asb                    [asb -k]
  10  恢复 /etc/asb                    [asb -l]
  11  第三方 BBR / DD 工具             [asb -b]
  12  卸载 Argo-Singbox                [asb -u] (需要严格的列对齐)
   0  退出
------------------------------------------------------------------
› 请选择：

◆ Argo-Singbox · 节点与订阅
-------------------------------------------------------------------
▸ 配置文件索引
文件索引        https://greencloud-asb.fiatnorm.pp.ua/15169e77-3af0-49c7-9aff-54cbb5018ed3/
自动适配        https://greencloud-asb.fiatnorm.pp.ua/15169e77-3af0-49c7-9aff-54cbb5018ed3/auto
原始明文        https://greencloud-asb.fiatnorm.pp.ua/15169e77-3af0-49c7-9aff-54cbb5018ed3/raw
Base64         https://greencloud-asb.fiatnorm.pp.ua/15169e77-3af0-49c7-9aff-54cbb5018ed3/base64
Clash          https://greencloud-asb.fiatnorm.pp.ua/15169e77-3af0-49c7-9aff-54cbb5018ed3/clash
Clash Provider https://greencloud-asb.fiatnorm.pp.ua/15169e77-3af0-49c7-9aff-54cbb5018ed3/proxies
sing-box       https://greencloud-asb.fiatnorm.pp.ua/15169e77-3af0-49c7-9aff-54cbb5018ed3/sing-box
Shadowrocket   https://greencloud-asb.fiatnorm.pp.ua/15169e77-3af0-49c7-9aff-54cbb5018ed3/shadowrocket (这一列也严格对齐)

▸ 自动适配订阅 QR
█████████████████████████████████████████████
█████████████████████████████████████████████
████ ▄▄▄▄▄ █▀ █▀▀██▄▄█▀▄▀ ▄▄ █▄▀▄█ ▄▄▄▄▄ ████
████ █   █ █▀ ▄ ██▄█ ▀ █ ▄█▄▀▀▀█▄█ █   █ ████
████ █▄▄▄█ █▀█ █▄   ▀█▀▄█▀▀▄██▄▀▀█ █▄▄▄█ ████
████▄▄▄▄▄▄▄█▄█▄█ ▀▄▀▄█▄▀▄▀ █ █▄▀ █▄▄▄▄▄▄▄████
████ ▄ ▄ █▄▄▄▄▄█▄█▄ ▀ ▄▀▀▀▀▀▄ ██▀▄█▄█ ▀ █████
████▄██ ██▄▄ █▄ ▄█▀█▀█ ▀█ ▄▀▀▄▄▄█ ▀▀█ ▄▀▄████
████▄ ▀█ ▀▄▄ ▄ ▄▀▀▀▀▄▄▀▀▀█▀▀▀▄ ▄ ▄▄▀▄▄ ▀▄████
████▀█▀▄▀▄▄ █ ██▀ ▄ ▄██▀▄ ▀███ ▄ ▀  █▀▄▄ ████
█████▄ ▄ ▄▄▄▀▄ █▄█▄ ▀▄▀▀▀▀▄  ▄▄█▀ ▄ ▄▄ ▀▄████
████▀█ ▀▀ ▄▀▀▄▄ ▄█▀█▀█▀█▀▀▀▀██▀▄▀▀▄  █▄▄ ████
████▄▀ ▄▀▀▄█   ▄▀▀▀▀▄▄▄▀▄▀▀▀▀ ██▀▄▄▀▄▄▄ ▄████
████▄▀█▀▄█▄ █▄ █▀ ▄ ▄▄▄█ ▀ ▀█▄  ▀█▄▀▀█▄▄ ████
████  ▄███▄▀██ █▄█▄ ▀  ▀▄██▀▀▄▀▄ █▄▀▄▀▄ ▄████
████ █▄▄▄▄▄▀ █  ▄█▀█▀▄██   ███▀ ▄▄█▄▄▄▄▄ ████
████▄█▄██▄▄▄  ▀▄▀▀▀▀█▄▀ ██▀▀▄▄▀  ▄▄▄ ▄▄██████
████ ▄▄▄▄▄ █▄ ██▀ ▄▄ █▄▀▀ ▀█▀█ █ █▄█ ██ ▄████
████ █   █ █ ███▄█▄█▀▄█▀▀▀▄ ▀▄▀▄▄  ▄ ▄▄▄▀████
████ █▄▄▄█ █ █▀ ▄█▀ ▀██▀▀ ▀▀▄█▀  ▀▀▄▀██▄ ████
████▄▄▄▄▄▄▄█▄██▄███▄▄▄████▄██▄█████▄▄▄▄▄▄████
█████████████████████████████████████████████
█████████████████████████████████████████████

▸ 明文节点
[节点 1]
vless://15169e77-3af0-49c7-9aff-54cbb5018ed3@142.248.136.72:443?encryption=none&security=tls&sni=greencloud-asb.fiatnorm.pp.ua&insecure=0&allowInsecure=0&type=ws&host=greencloud-asb.fiatnorm.pp.ua&path=%2Fargo-vl%3Fed%3D2560#Argo-Vl

[节点 2]
vless://15169e77-3af0-49c7-9aff-54cbb5018ed3@142.248.136.72:443?encryption=none&security=tls&sni=greencloud-asb.fiatnorm.pp.ua&insecure=0&allowInsecure=0&type=ws&host=greencloud-asb.fiatnorm.pp.ua&path=%2Fargo-vl2%3Fed%3D2560#Argo-Vl2

[节点 3]
trojan://15169e77-3af0-49c7-9aff-54cbb5018ed3@142.248.136.72:443?security=tls&sni=greencloud-asb.fiatnorm.pp.ua&insecure=0&allowInsecure=0&type=ws&host=greencloud-asb.fiatnorm.pp.ua&path=%2Fargo-tr%3Fed%3D2560#Argo-Tr

[节点 4]
vmess://eyJ2IjoiMiIsInBzIjoiQXJnby1WbSIsImFkZCI6IjE0Mi4yNDguMTM2LjcyIiwicG9ydCI6IjQ0MyIsImlkIjoiMTUxNjllNzctM2FmMC00OWM3LTlhZmYtNTRjYmI1MDE4ZWQzIiwiYWlkIjoiMCIsInNjeSI6ImF1dG8iLCJuZXQiOiJ3cyIsInR5cGUiOiJub25lIiwiaG9zdCI6ImdyZWVuY2xvdWQtYXNiLmZpYXRub3JtLnBwLnVhIiwicGF0aCI6Ii9hcmdvLXZtP2VkPTI1NjAiLCJ0bHMiOiJ0bHMiLCJzbmkiOiJncmVlbmNsb3VkLWFzYi5maWF0bm9ybS5wcC51YSIsImFscG4iOiIifQ==

✓ Sing-box 已关闭。
✓ Argo 已关闭。 (这里都使用黄色，开启都使用绿色)

◆ Argo-Singbox · 集中配置
-------------------------------------------------------------------
▸ 基础配置
   1  Token / Argo 域名
   2  Cloudflare 优选入口
   3  Argo Tunnel 回源端口（节点端口依次顺延）
   4  全局 UUID

▸ 节点与分流
   5  查看节点
   6  添加节点
   7  修改节点
   8  删除节点
   9  WARP 网址分流
   0  返回
-------------------------------------------------------------------
› 请选择：

◆ Argo-Singbox · 完整诊断
-------------------------------------------------------------------
▸ 运行概览（颜色区别于下面的运行配置）
公网 IP      173.231.53.138
脚本版本     v2.11.4
内存         415/3883 MiB (11%)
优选入口     142.248.136.72:443
Argo 回源    127.0.0.1:3010(这列对齐)

▸ 配置与组件
✓ 项目配置：有效
✓ Sing-box 配置：有效
✓ Nginx 配置：有效
✓ Token：已配置且服务文件一致
组件版本   脚本 v2.11.4 · Sing-box 1.13.0-rc.4 · Cloudflared 2026.7.0
• WARP：未启用

▸ 运行检查
✓ nginx：运行正常
✓ asb-sing-box：运行正常
✓ /argo-vl：公网 WebSocket 握手正常
✓ /argo-vl2：公网 WebSocket 握手正常
✓ /argo-tr：公网 WebSocket 握手正常
• /argo-vm：公网握手探测超时，未作为安装失败（请用客户端实测）(使用黄色或红色)

▸ 最近日志
2026-07-09T22:38:56+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:56 INFO [4160947199 0ms] inbound/vless[Argo-Vl]: inbound connection from 144.34.236.165:10702
2026-07-09T22:38:56+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:56 INFO [4160947199 0ms] inbound/vless[Argo-Vl]: [0] inbound connection to 91.108.56.112:80
2026-07-09T22:38:56+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:56 INFO [4160947199 0ms] outbound/direct[direct]: outbound connection to 91.108.56.112:80
2026-07-09T22:38:56+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:56 INFO [1245479584 0ms] inbound/vless[Argo-Vl]: inbound connection from 144.34.236.165:10718
2026-07-09T22:38:56+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:56 INFO [1245479584 0ms] inbound/vless[Argo-Vl]: [0] inbound connection to 91.108.56.112:80
2026-07-09T22:38:56+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:56 INFO [1245479584 0ms] outbound/direct[direct]: outbound connection to 91.108.56.112:80
2026-07-09T22:38:58+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:58 INFO [3626160319 0ms] inbound/vless[Argo-Vl]: inbound connection from 144.34.236.165:10722
2026-07-09T22:38:58+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:58 INFO [3626160319 0ms] inbound/vless[Argo-Vl]: [0] inbound connection to github.com:443
2026-07-09T22:38:58+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:58 INFO [3626160319 0ms] outbound/direct[direct]: outbound connection to github.com:443
2026-07-09T22:38:58+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:58 INFO [4156931583 0ms] inbound/vless[Argo-Vl]: inbound connection from 142.248.136.72:10736
2026-07-09T22:38:59+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:59 INFO [4013056310 0ms] inbound/vless[Argo-Vl]: inbound connection from 144.34.236.165:10746
2026-07-09T22:38:59+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:59 INFO [4013056310 0ms] inbound/vless[Argo-Vl]: [0] inbound connection to alive.github.com:443
2026-07-09T22:38:59+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:38:59 INFO [4013056310 0ms] outbound/direct[direct]: outbound connection to alive.github.com:443
2026-07-09T22:39:02+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:02 ERROR [4156931583 4.17s] inbound/vless[Argo-Vl]: process connection from 142.248.136.72:10736: EOF
2026-07-09T22:39:04+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:04 INFO [2080243965 0ms] inbound/vless[Argo-Vl2]: inbound connection from 142.248.136.72:40558
2026-07-09T22:39:10+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:10 ERROR [2080243965 6.42s] inbound/vless[Argo-Vl2]: process connection from 142.248.136.72:40558: EOF
2026-07-09T22:39:11+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:11 INFO [2382046508 0ms] inbound/trojan[Argo-Tr]: inbound connection from 142.248.136.72:48864
2026-07-09T22:39:12+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:12 INFO [1189298886 0ms] inbound/vless[Argo-Vl]: inbound connection from 144.34.236.165:16960
2026-07-09T22:39:12+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:12 INFO [1189298886 0ms] inbound/vless[Argo-Vl]: [0] inbound connection to mobile.events.data.microsoft.com:443
2026-07-09T22:39:12+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:12 INFO [1189298886 0ms] outbound/direct[direct]: outbound connection to mobile.events.data.microsoft.com:443
2026-07-09T22:39:14+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:14 INFO [111028087 0ms] inbound/vless[Argo-Vl]: inbound connection from 144.34.236.165:37858
2026-07-09T22:39:14+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:14 INFO [111028087 0ms] inbound/vless[Argo-Vl]: [0] inbound connection to 91.108.56.112:80
2026-07-09T22:39:14+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:14 INFO [111028087 0ms] outbound/direct[direct]: outbound connection to 91.108.56.112:80
2026-07-09T22:39:15+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:15 INFO [1510666581 0ms] inbound/vless[Argo-Vl]: inbound connection from 144.34.236.165:37866
2026-07-09T22:39:15+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:15 INFO [1510666581 0ms] inbound/vless[Argo-Vl]: [0] inbound connection to 91.108.56.112:80
2026-07-09T22:39:15+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:15 INFO [1510666581 0ms] outbound/direct[direct]: outbound connection to 91.108.56.112:80
2026-07-09T22:39:16+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:16 INFO [2668606310 0ms] inbound/vless[Argo-Vl]: inbound connection from 144.34.236.165:37870
2026-07-09T22:39:16+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:16 INFO [2668606310 0ms] inbound/vless[Argo-Vl]: [0] inbound connection to 91.108.56.112:80
2026-07-09T22:39:16+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:16 INFO [2668606310 0ms] outbound/direct[direct]: outbound connection to 91.108.56.112:80
2026-07-09T22:39:20+08:00 greencloud.fiatnorm.pp.ua sing-box[329]: +0800 2026-07-09 22:39:20 ERROR [2382046508 9.23s] inbound/trojan[Argo-Tr]: process connection from 142.248.136.72:48864: EOF

◆ Argo-Singbox · 安装 / 更新
-------------------------------------------------------------------
▸ 请选择安装来源
   1  使用当前 VPS 本地脚本重装   [不更新项目脚本]
   2  从 GitHub 获取最新脚本安装  [可更新项目脚本](列对齐)
   0  返回
-------------------------------------------------------------------
› 请选择：
