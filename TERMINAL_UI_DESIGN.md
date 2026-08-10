# AGS v1.3.2 · 终端 UI 合同

## 视觉规则

- 语义宽度固定为 64 列，显示宽度以 `C.UTF-8` 计算。
- 非 TTY、`TERM=dumb` 或设置 `NO_COLOR` 时禁用 ANSI。
- 分区和分隔线使用亮蓝；键名与字标亮青；标题与输入亮洋红；正文 ANSI `97` 亮白。
- 图标语义固定为 `◆ / ▸ / ✓ / ! / ✗ / • / ›`。
- 页面提示仅使用 `main/back/cancel/default/none`：`0 · 退出/返回/取消` 或 `Enter · 默认 | 0 · 取消`。
- 交互子页统一为“状态或说明 → 操作”，只读页不显示 `0` 提示。

## 主面板

状态顺序：

```text
Argo Tunnel
代理核心 · Sing-box
WARP 分流
多路复用 · h2mux
TCP Brutal · 模块状态与带宽
节点概览 · Vless n · Vmess n · Trojan n
Argo 域名
优选入口
Argo 回源
组件版本
```

主菜单：

```text
1  节点订阅       ags -n
2  服务启停       ags -a
3  参数配置       ags -c
4  流量统计       ags -t
5  运行诊断       ags -x
6  项目安装       ags -i
7  组件更新       ags -v
8  备份恢复       ags -k
9  BBR / DD       ags -b
10 项目卸载       ags -u
0  退出脚本
```

主菜单和短参数只提供以上已列出的管理页面。

## 页面合同

- 节点订阅顺序：订阅面板、自适应、原始、Base64、Clash/Mihomo、Sing-box；只显示一张自适应 QR。
- 节点表宽度：`13/6/14/5/18`，协议显示 `Vless/Vmess/Trojan`，过长字段以 `~` 截断。
- 服务启停：Argo Tunnel、Sing-box Core、重启服务；重启先执行 `daemon-reload`。
- 参数配置：Argo、节点、WARP、h2mux / TCP Brutal；传输页按“状态与带宽 → 安装/更新 → 设置带宽”排列，WARP 留空添加/删除为 no-op。
- TCP Brutal 安装：先显示内核、头文件和兼容性结论；不支持时不显示确认执行，支持时明确说明 DKMS、内核头文件和开机加载变更。
- 流量统计：统计状态、Clash API 全局上传/下载合计、统计操作。
- 诊断：明确显示“已通过 / 无效 / 未运行”，检查 h2mux 配置和 `brutal` 模块状态，仅失败时展开相关日志。
- 组件更新：cloudflared 与 Sing-box 分别比较、确认、校验、替换并支持回滚。
- 备份恢复：只处理 `nodes.conf`，拒绝路径穿越、链接和特殊文件。

## 验收

- 所有分隔线为 64 列。
- `NO_COLOR=1 TERM=dumb` 输出无 `ESC`。
- 首页、帮助和参数解析与本合同列出的页面一致。
- 品牌使用 `AGS`，命令使用 `ags` 或 `AGS`，路径和服务名使用 `ags`。
