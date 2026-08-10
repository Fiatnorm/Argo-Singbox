# AGS v1.3.3

AGS 是单内核项目。运行时只安装和管理官方 Sing-box，保留节点、订阅、WARP、长期全局流量统计、诊断、备份恢复和安装更新能力。

## 项目结构

- `ags.sh`：唯一安装与管理入口。
- `ags.env.example`：配置格式示例。
- `ags.sh.sha256`：入口脚本校验值。
- `reference/sba/`：Sing-box 路线的只读参考代码；2026-08-10 已核验与上游 `fscarmen/sba` `main` 的 `9388bac7cba21b7ce3d5acd6698db9359f328bf1` 一致。
- `TERMINAL_UI_DESIGN.md`：64 列终端 UI 合同。
- `AGENTS.md`：工程、验证和发布约束。

原始组合项目工作区及其 `sba/` 参考树不会被本项目自动移动、删除或覆盖。

## 支持范围

- Debian / Ubuntu + systemd，amd64 / arm64。
- 固定 Cloudflare Argo Token。
- Sing-box 官方稳定版 `SagerNet/sing-box` `v1.13.18`。
- VLESS、VMess、Trojan WebSocket。
- 全部 WS 节点启用 h2mux 多路复用，并在服务器已加载 `brutal` 内核模块时启用 TCP Brutal。
- 每节点 SOCKS5、Cloudflare 官方 WARP SOCKS5 分流。
- 原始、Base64、Clash/Mihomo、Sing-box 与 User-Agent 自适应订阅。
- Clash API + SQLite 的每分钟全局上传/下载长期统计。

Sing-box 客户端订阅只是客户端格式，不是第二个服务端内核。

## 安装与管理

当前拆分结果是本地项目目录，尚未执行 GitHub 建仓或发布。可先在目标 VPS 上传完整项目目录，再校验并执行：

```bash
cd /path/to/AGS
sha256sum -c ags.sh.sha256
bash ags.sh -i
```

未来发布到 `Fiatnorm/AGS` 后，脚本的“在线更新”会从同一仓库读取并校验 `ags.sh`。

安装后的主要路径：

```text
/etc/ags/ags.sh
/etc/ags/bin/sing-box
/etc/ags/bin/cloudflared
/etc/ags/config/ags.env
/etc/ags/config/nodes.conf
/etc/ags/config/sing-box.json
/etc/ags/data/traffic.db
/etc/ags/subscriptions/
/etc/nginx/conf.d/ags.conf
/etc/systemd/system/ags-core.service
/etc/systemd/system/ags-tunnel.service
/etc/systemd/system/ags-traffic.service
/etc/systemd/system/ags-traffic.timer
/usr/local/bin/ags
/usr/local/bin/AGS
```

管理入口：

```text
ags        控制中心
ags -n     节点订阅
ags -a     服务启停
ags -c     参数配置
ags -t     流量统计
ags -x     运行诊断
ags -i     项目安装
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

`ags -n` 按订阅面板、自适应、原始、Base64、Clash/Mihomo、Sing-box 的顺序显示链接，只为自适应订阅显示一张 QR。

## 流量统计

Sing-box 通过 `experimental.clash_api` 在 `127.0.0.1:18085` 提供本机 REST API。采集器每分钟读取 `/connections` 的 `uploadTotal` 和 `downloadTotal`，按进程启动标识与上次原始计数计算增量，再写入 SQLite。

`ags-core.service` 停止前会执行一次最终采集；核心重启、PID 变化或原始计数回退时会建立新基线并继续累加。重置操作会清空持久化总量，同时保留当前进程原始计数作为新基线，避免重置前流量再次计入。数据库只保存一组全局累计值和一组当前进程基线，不创建或读取节点明细。

## h2mux 与 TCP Brutal

服务端三个 WS 入站固定启用 h2mux 兼容的多路复用和 padding。Clash/Mihomo 与 Sing-box 订阅会生成对应的客户端多路复用配置；原始 URI 与 Base64 订阅不写入非标准私有参数。

脚本先检查已加载模块，再尝试 `modprobe brutal`。检测成功时服务端和两类结构化订阅启用 TCP Brutal；否则只启用 h2mux。默认上下行带宽均为 1000 Mbps，可在 `ags -c` 的“h2mux / TCP Brutal”页面修改。

同一页面提供 TCP Brutal 安装与更新。执行安装前会验证 Linux、内核不低于 4.9、非 WSL/容器、当前内核存在 `/lib/modules` 且启用 `CONFIG_MODULES`，并按官方安装器规则检查 APT、DKMS 以及当前运行内核精确对应的 `linux-headers-$(uname -r)`。内核头文件未安装时，只有该精确软件包在当前 APT 源中可安装才会继续；不能以其他版本头文件替代。内核低于 5.8 时提示仅支持 IPv4，低于 4.13 时额外提示 `fq pacing` 要求。不通过预检时不会下载文件、安装软件包或修改内核。用户确认后会刷新 APT、再次复核并安装依赖，通过后才下载固定在上游提交 `f11e52d88c7ad2285896de018c2d96d4687f0ab6` 的 [tcp-brutal 官方 DKMS 安装器](https://github.com/apernet/tcp-brutal)，以及官方稳定版 `v1.0.3` DKMS 模块包；两者分别通过固定 SHA256 校验后，使用安装器的 `--local` 模式安装。模块成功加载后，脚本会重新生成服务端及订阅配置并验证服务重启。

## 从旧组合项目迁移

AGS 不会自动接管 `/etc/afs`，避免迁移时误停或覆盖现有旧项目。推荐流程：

1. 在旧项目执行 `af -k` 备份 `nodes.conf`。
2. 停止旧项目，确认目标端口和 Nginx 配置不冲突。
3. 安装 AGS，重新填写 Token、域名、UUID、优选入口和 WARP 参数。
4. 使用 `ags -k` 恢复节点备份，再执行 `ags -x`。

同一 VPS 若同时运行两个拆分项目，必须为回源端口、统计端口、全部节点端口、Argo 域名和 Nginx server 配置分别避让；默认配置不用于并行安装。

## 验证边界

本地最低验证：

```bash
bash -n ags.sh
bash tests/tcp-brutal-smoke.sh
bash tests/generation-smoke.sh
bash tests/traffic-global-smoke.sh
bash tests/installer-migration-smoke.sh
sha256sum -c ags.sh.sha256
grep -n $'\r' ags.sh && exit 1 || true
```

本地检查不能替代 VPS 上的 `nginx -t`、Sing-box 配置检查、systemd、Clash API 实时计数、Cloudflare Tunnel 及公网 WS 实测。
