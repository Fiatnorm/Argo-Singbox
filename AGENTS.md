# AGENTS.md

## 项目定位

本仓库是 `Argo-Singbox`，不是原版 `sba`。它是面向 Debian/Ubuntu、systemd、固定 Cloudflare Argo Token 的中文轻量管理脚本。

主要文件：

- `argo-singbox.sh`：唯一安装和管理入口。
- `argo-singbox.env.example`：配置格式示例，不会被脚本自动读取。
- `README.md`：面向用户的安装、更新和运维说明。
- `sba/`：原版 SBA 本地对照树。除非任务明确要求更新对照版本，否则不得修改、删除或提交该目录。

安装后的主要文件：

- `/etc/asb/argo-singbox.sh`
- `/etc/asb/bin/sing-box`
- `/etc/asb/bin/cloudflared`
- `/etc/asb/asb.env`
- `/etc/asb/nodes.conf`
- `/etc/asb/nodes.txt`
- `/etc/asb/backup/`
- `/usr/local/bin/asb`

## 产品边界

保持以下范围：

- 仅支持 Debian/Ubuntu + systemd。
- 仅支持 amd64 和 arm64。
- 仅支持固定 Argo Token，不加入临时隧道、Argo JSON 或 Cloudflare API 建隧道。
- 默认保留 VLESS、VMess、Trojan 各一个 WS 节点，并允许通过 `asb -c` 动态添加、修改或删除这三种协议的 WS 节点。
- 允许节点按 inbound tag 与 WS 路径绑定独立 SOCKS5 出站。
- 允许用户指定目标网址优先通过 Cloudflare 官方 WARP 客户端的本地 SOCKS5 proxy 出站；未命中时仍遵循节点 SOCKS5 或 direct。
- 保持中文交互，不加入英文模式。
- 日常管理必须使用 VPS 本地安装脚本，不得改成每次执行都从 GitHub 拉取仓库脚本。
- BBR 不是项目内置能力，只能作为明确标注的第三方外部工具保留。

不要因为“对齐原版 SBA”而扩大产品范围。只对齐可靠性、回退、版本选择和运行语义。

## 命名规则

- 仓库入口必须使用 `argo-singbox.sh`，不要重新创建 `sba.sh`。
- 管理命令保持为 `asb`。
- systemd 服务保持为 `asb-sing-box.service` 和 `asb-cloudflared.service`。
- 核心二进制必须放在 `/etc/asb/bin/`，不得写入或删除 `/usr/local/bin/sing-box`、`/usr/local/bin/cloudflared`。
- 新增项目文件优先使用 `argo-singbox` 或 `asb` 前缀，避免与原版 SBA 文件混淆。

## 安全约束

安装、更新和卸载修改必须满足：

- 不得无条件删除整个 `/etc/asb`。
- 修改已有配置前必须保留备份，仅重建本项目管理的文件。
- 不得覆盖第三方同名 systemd 服务。只有带本项目 `Description=SBA ...` 或 `Description=Argo-Singbox ...` 标记的旧服务可以迁移。
- 卸载必须检查 `/etc/asb/managed` 所有权标记。
- 卸载只删除本项目私有核心、服务、Nginx 配置、`asb` 链接和节点文件。
- 核心更新必须先比较版本并请求确认。
- 下载必须包含连接超时、总超时、重试、GitHub 代理回退和 SHA256 校验。
- 更新流程必须遵循：下载到临时文件 → 校验可执行性 → `sing-box check` → 备份 → 原子替换 → 重启验证 → 失败回滚。
- 不得在脚本或示例文件中加入固定公共 UUID、Token 或项目公共域名。
- 不得嵌入公共 WARP WireGuard 私钥、固定 WARP 账户或非官方 WARP 注册凭据；WARP 使用用户 VPS 上安装的 Cloudflare 官方客户端。
- Argo 域名必须由用户输入；首次安装 UUID 应自动随机生成。

## 交互和运行语义

- 优选入口使用单行 `域名/IP:端口` 输入；IPv6 使用 `[地址]:端口`。
- `asb -n` 必须输出当前全部动态节点、二维码、原始订阅和 Base64 订阅地址。
- 节点连接地址使用优选入口，WebSocket Host 与 TLS SNI 使用 Argo 域名。
- 修改 Token 或优选入口后，应重新生成节点并执行健康检查。
- 健康检查必须测试 `/etc/asb/nodes.conf` 中的全部 WS 路径，默认包括 `/argo-vl`、`/argo-vm`、`/argo-tr`。
- `asb -c` 必须集中管理 Token、Argo 域名、优选入口、本地端口、UUID、动态节点、节点 SOCKS5 出站和 WARP 目标网址。
- WARP 域名规则必须位于节点 SOCKS5 规则之前，保持 `目标网址 WARP → 节点 SOCKS5 → direct` 的优先级。
- `asb -x` 必须检查配置、Token、服务、动态端口、全部公网 WS 路径、核心版本、WARP（启用时）和最近日志。
- `asb -k/-l` 必须校验 `/etc/asb/managed`；恢复失败必须自动回滚。
- 终端配色必须在非 TTY、`TERM=dumb` 或 `NO_COLOR` 环境自动关闭，不得向日志和管道写入 ANSI 控制符。
- 状态诊断保持简洁，并包含公网 IP、脚本/核心版本、内存、systemd 状态、监听端口和最近错误。
- 普通启停、查看节点、修改配置和卸载不得执行 `git pull` 或重新下载仓库脚本。
- `asb -i` 必须提供“VPS 本地脚本重装”和“GitHub 最新脚本安装”两种模式；仅 GitHub 模式联网更新项目脚本，校验通过后由最新脚本继续安装，其他日常命令仍运行 VPS 本地脚本。

## 修改要求

- 优先小范围修改现有函数，不做无关重构。
- 保持 `set -Eeuo pipefail`。
- 所有变量引用都应正确加引号，临时文件使用 `mktemp`。
- 保持脚本为 LF 行尾；不要引入 CRLF。
- 修改命令、菜单、路径或行为时，同步更新 `README.md`。
- 不要修改用户已有的无关文件或清理未跟踪的 `sba/` 对照树。
- 未在真实 VPS 上验证时，不得宣称 systemd、Nginx、Cloudflare 或公网 WS 已端到端通过。

## 最低验证

在提交修改前执行：

```bash
bash -n argo-singbox.sh
git diff --check
```

涉及输入解析或节点生成时，还要执行相应函数级测试。涉及安装、更新、卸载、systemd、Nginx 或 Cloudflare 时，应尽可能在 Debian/Ubuntu 测试机验证，并至少检查：

```bash
nginx -t
/etc/asb/bin/sing-box check -c /etc/asb/sing-box.json
systemctl is-active nginx asb-sing-box asb-cloudflared
ss -lnt
journalctl -u asb-sing-box -u asb-cloudflared -n 100 --no-pager
```

如果没有 VPS 环境，应明确列出未完成的运行时验证，不得用静态检查替代运行证明。
