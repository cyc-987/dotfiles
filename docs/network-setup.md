# Mihomo 与 Tailscale：配置记录与新机部署

本记录说明 2026-10-02 在 `cpu5` 上完成的配置和故障排查。已验证以下访问路径：本机应用 → Mihomo `127.0.0.1:63796` → Tailscale 用户态 SOCKS5 代理 `127.0.0.1:1055` → `100.97.69.51:8080` 的 Bifrost 服务。服务返回 HTTP 200。

原机没有 sudo 权限。原机使用 Tailscale `1.102.4` 和 Mihomo `v1.19.27`。操作系统和架构为 Linux amd64。

仓库保存共享脚本和配置模板。每台设备单独保存运行状态、订阅凭据和程序二进制文件。

## 1. 工作方式与使用范围

| 组件 | 地址或路径 | 用途 |
| --- | --- | --- |
| Tailscale SOCKS5 / HTTP 代理 | `127.0.0.1:1055` | tailscaled 同时提供这两种代理协议 |
| Tailscale 本地控制套接字 | `~/.local/state/tailscale/tailscaled.sock` | `ts` 命令通过此套接字连接用户态守护进程 |
| Mihomo 代理入口（mixed-port） | `127.0.0.1:63796` | 接收应用的 HTTP / SOCKS 代理请求 |
| Mihomo 控制接口（controller） | `127.0.0.1:63797` | 查询运行模式、代理节点和策略组 |

用户态 Tailscale 通过 SOCKS5 / HTTP 代理接收应用流量。它不在系统中创建普通 TUN 路由。普通 `ping` 和未设置代理的 SSH 不会自动使用上述访问路径。[Tailscale 用户态说明](https://tailscale.com/docs/concepts/userspace-networking)

Mihomo 继续按现有规则分流公网请求。命中海外代理组的请求继续使用原代理。命中“全球直连”或最终兜底规则的请求先交给本机 tailscaled。

未配置 Exit Node 时，tailscaled 将已知虚拟内网（tailnet）节点的流量送入 Tailscale。其他目标的流量使用主机常规网络。因此，将请求交给 Tailscale 代理节点，不表示公网流量也使用远端出口。[已核对版本的拨号实现](https://github.com/tailscale/tailscale/blob/v1.102.4/net/tsdial/tsdial.go#L547)

原机未启用 Exit Node、子网路由接收或 Tailscale SSH。原机保存的 DNS 偏好为开启。访问虚拟内网自身的 `100.x` 节点，无需接收其他机器发布的子网路由。如果主机还使用 NetBird 等网络，对应网络继续维护其地址和 DNS。

## 2. config.yaml 的三处更改

原机配置文件为 `~/Softwares/mihomo/config.yaml`。原始备份为同一目录中的 `config.yaml.bak.20261002-145504-034026`。

仓库模板已包含以下三处更改。原有规则、其他代理组和公开规则来源保持不变。

### 添加本地 Tailscale SOCKS5 出口

```yaml
proxies:
- name: Tailscale
  type: socks5
  server: 127.0.0.1
  port: 1055
  udp: true
```

### 将“全球直连”的出口固定为 Tailscale

原选择列表包含 `DIRECT`、`REJECT` 和多个代理组。修改后的列表只有一个成员：

```yaml
- name: 🎯 全球直连
  type: select
  proxies:
  - Tailscale
```

本机已有的 `LocalAreaNetwork` 规则包含 `IP-CIDR,100.64.0.0/10,no-resolve`。因此，测试节点 `100.97.69.51` 匹配此组，无需逐台添加 IP 规则。

如果其他网络也使用此地址范围，不要仅凭网段判断节点是否属于本虚拟内网。

### 修改最终兜底规则

```diff
- MATCH,🐟 漏网之鱼
+ MATCH,Tailscale
```

直接指定 `Tailscale`，可以避免兜底策略组继续使用之前保存的选择。Mihomo 仍先匹配前面的规则。

仓库模板还将唯一的私有代理订阅 URL 替换为 `__MIHOMO_SUBSCRIPTION_URL__`。`configure-mihomo.py` 在本机填入真实地址。生成配置的文件权限为 600。

模板保留了原机的 ZJU/PT 等个人规则。如果需要其他分流规则，先编辑模板，再生成配置。

## 3. 仓库文件与设备文件

| 仓库文件 | 部署位置或用途 |
| --- | --- |
| `tailscale/.local/bin/ts` | 链接到 `~/.local/bin/ts` |
| `tailscale/.local/bin/tailscale-watchdog` | 链接到 `~/.local/bin/tailscale-watchdog` |
| `mihomo/.local/bin/mihomo-run` | 链接到 `~/.local/bin/mihomo-run` |
| `mihomo/.config/mihomo/config.yaml.template` | 共享分流模板，链接到本机供查看 |
| `shell/.config/shell/network-proxy.sh` | 提供 Bash/zsh 代理环境函数 |
| `scripts/install-network-tools.sh` | 将官方二进制文件下载到 `~/.local/bin` |
| `scripts/link-network-dotfiles.sh` | 备份旧文件，建立脚本和模板链接 |
| `scripts/configure-mihomo.py` | 使用仓库模板和本机订阅生成运行配置 |
| `scripts/check-network.sh` | 查询运行状态，比较两条代理访问路径 |

每台设备单独维护以下文件。仓库已设置对应的忽略规则。

- `~/.local/state/tailscale/`：节点状态、密钥、套接字、锁和日志。
- `~/.config/mihomo/subscription.url`：私有代理订阅地址。
- `~/.config/mihomo/config.yaml`：包含本机订阅地址的生成配置。
- Mihomo 的 `cache.db`、`sub/`、`rule/` 和 Geo 数据。可自行下载这些数据，或从可信设备传输缓存。
- `tailscale`、`tailscaled`、`mihomo` 二进制文件。按操作系统和 CPU 架构安装这些文件。

在新设备上登录 Tailscale，建立该设备的节点。不要复制其他设备的 `tailscaled.state`。

## 4. 在无 sudo 权限的新 Linux 机器上部署

在 Bash 中执行以下示例。所需工具为 Git、curl、tar、gzip、install、flock、ss 和 Python ≥ 3.8。检查脚本还需要 jq。进程查询示例还需要 rg。

Mihomo 和 Tailscale 均可安装到家目录，无需修改系统服务。

### 4.1 获取仓库并安装二进制文件

```bash
mkdir -p "$HOME/Projects"
git clone git@github.com:cyc-987/dotfiles.git "$HOME/Projects/dotfiles"
cd "$HOME/Projects/dotfiles"
bash scripts/install-network-tools.sh
export PATH="$HOME/.local/bin:$PATH"
```

如果已有仓库，使用现有仓库目录。安装脚本默认获取官方最新稳定版。Tailscale 版本来自稳定通道，Mihomo 版本来自最新正式 Release。

如需安装指定版本，设置 `TAILSCALE_VERSION` 和 `MIHOMO_VERSION`。版本号可带 `v` 前缀。未设置变量，或将变量设为 `latest` 时，脚本自动查询稳定版本。查询需要 Python 3。

Linux x86_64 使用 amd64 包，其中 Mihomo 使用 amd64-v1 包。aarch64/arm64 使用 arm64 包。脚本保留已有的可执行程序，并打印实际版本。脚本仅在需要安装对应程序时查询或使用版本号，不自动升级已有程序。

升级前，先自行备份原程序。然后停止对应服务，再安装新版本。

Tailscale 下载地址为 `https://dl.tailscale.com/stable/tailscale_版本_架构.tgz`。压缩包包含 `tailscale` 和 `tailscaled`。

原机曾将下载包保存到 `~/.local/opt/tailscale`。解压后，将这两个文件复制到 `~/.local/bin`，并设置可执行权限。新安装脚本将下载文件保存到 `~/.local/opt/network-downloads`。[官方静态发行包](https://dl.tailscale.com/stable/#static)

Mihomo 安装包来自对应版本的官方 GitHub Release。下载 `.gz` 文件，解压后安装到 `~/.local/bin/mihomo`。[Mihomo 最新正式发布页](https://github.com/MetaCubeX/mihomo/releases/latest)

如果新机器无法下载，在能访问下载站的设备上取得官方安装包。安装包的版本和架构必须相同。然后将安装包传输到目标机器。不要在 macOS 上直接使用 Linux 可执行文件。

### 4.2 链接脚本和模板

```bash
cd "$HOME/Projects/dotfiles"
bash scripts/link-network-dotfiles.sh
```

脚本先将同名旧文件备份到 `~/.local/share/dotfiles-backups/network-时间-PID/`。然后，脚本建立指向仓库的链接。脚本保留已经正确的链接。

脚本不改变现有运行配置、登录状态或服务。建立链接前，确认仓库将长期保存在固定位置。

也可使用 GNU Stow 建立链接。先自行备份旧文件，再预览链接冲突。上述脚本和 Stow 只选择一种。

```bash
stow --no-folding --simulate --verbose --dir "$HOME/Projects/dotfiles" --target "$HOME" tailscale mihomo shell
stow --no-folding --verbose --dir "$HOME/Projects/dotfiles" --target "$HOME" tailscale mihomo shell
```

仅在已安装 Stow 时使用此方法。`--no-folding` 使 Stow 只链接文件。这样，之后生成的私有配置不会通过目录链接写入仓库。不要使用 `--adopt` 处理冲突。[Stow 目录链接说明](https://github.com/aspiers/stow/blob/master/doc/stow.texi#L413)

### 4.3 保存本机私有订阅并生成配置

在 Bash 中输入完整的代理订阅 URL。输入内容不会回显。以下命令将地址保存在仓库外部：

```bash
mkdir -p "$HOME/.config/mihomo"
umask 077
read -r -s -p 'Mihomo 订阅 URL: ' mihomo_subscription_url
printf '\n'
printf '%s\n' "$mihomo_subscription_url" > "$HOME/.config/mihomo/subscription.url"
unset mihomo_subscription_url
chmod 600 "$HOME/.config/mihomo/subscription.url"
python3 "$HOME/Projects/dotfiles/scripts/configure-mihomo.py"
```

输入 `proxy-providers.subscription0.url` 所需的完整 URL。原机可从 `~/Softwares/mihomo/config.yaml` 查看此字段。不要将真实地址写入公开仓库。

生成配置的路径为 `~/.config/mihomo/config.yaml`。如果已有配置的内容不同，脚本先将旧配置备份为 `config.yaml.bak.时间`。如果内容相同，脚本不重复写入。

如果输出文件是符号链接，脚本会拒绝写入。如果父目录链接使输出文件位于仓库内，脚本也会拒绝写入。这两项检查防止凭据写入仓库。

### 4.4 启动用户态 Tailscale 并登录

```bash
mkdir -p "$HOME/.local/state/tailscale"
chmod 700 "$HOME/.local/state/tailscale"
nohup "$HOME/.local/bin/tailscale-watchdog" \
  </dev/null >>"$HOME/.local/state/tailscale/watchdog-launch.log" 2>&1 &
```

等待本地控制套接字建立。使用以下命令检查状态和日志。如果提示服务尚未运行，先查看日志，再执行检查命令。

```bash
"$HOME/.local/bin/ts" status
tail -n 30 "$HOME/.local/state/tailscale/tailscaled.log"
```

首次加入虚拟内网时，执行以下命令：

```bash
"$HOME/.local/bin/ts" up \
  --hostname="$(hostname -s)" \
  --accept-routes=false \
  --accept-dns=true \
  --ssh=false
```

打开命令输出的登录链接，认证新机器。上述参数使用本方案的偏好，未指定 Exit Node。

节点状态保存在 `~/.local/state/tailscale/tailscaled.state`。正常重启守护进程时，Tailscale 复用当前机器的登录状态。

`tailscale` 是控制命令。`tailscaled` 是常驻守护进程。`ts` 是包装命令，用于统一指定自定义控制套接字。[官方用户态启动方式](https://tailscale.com/docs/concepts/userspace-networking)

### 4.5 启动 Mihomo

先查询已有实例和监听端口。不要重复启动 Mihomo。

```bash
ss -ltnp | rg ':(63796|63797)\b'
ps -u "$USER" -o pid,ppid,args | rg '[m]ihomo'
```

如果旧实例从 `~/Softwares/mihomo/` 启动，先在原终端结束该实例。也可对已确认属于本用户的 PID 执行 `kill -TERM PID`。不要使用旧故障排查记录中的 PID。

在前台或 tmux 中执行以下命令：

```bash
"$HOME/.local/bin/mihomo-run"
```

也可在确认没有其他实例后，使用以下命令在后台启动：

```bash
mkdir -p "$HOME/.local/state/mihomo"
chmod 700 "$HOME/.local/state/mihomo"
nohup "$HOME/.local/bin/mihomo-run" \
  </dev/null >>"$HOME/.local/state/mihomo/mihomo.log" 2>&1 &
```

`mihomo-run` 使用配置文件和数据目录的绝对路径。它持有单实例锁，并检查旧实例是否占用固定的 63796/63797 端口。此脚本不自动重启 Mihomo。

如果继续使用原机的程序或配置位置，可分别设置 `MIHOMO_BIN`、`MIHOMO_CONFIG` 和 `MIHOMO_DATA_DIR`。可使用 `MIHOMO_STATE_DIR` 设置锁目录。配置中的端口必须与本方案一致。

### 4.6 设置终端代理

将以下代码合并到 `~/.bashrc` 或 `~/.zshrc`：

```bash
[ ! -f "$HOME/.config/shell/network-proxy.sh" ] || . "$HOME/.config/shell/network-proxy.sh"
```

重新读取 shell 启动文件。在需要代理的终端运行 `proxy`。运行 `noproxy`，清除代理环境变量。

这些函数同时处理大写和小写的 HTTP/HTTPS/ALL_PROXY 变量。SOCKS 使用 `socks5h`。如果已有同名函数，用仓库版本替换原定义。

`NO_PROXY` 只包含 localhost、127.0.0.1 和 ::1。不要将需要经过 Tailscale 的 `100.x` 地址加入代理绕过列表。

环境变量只影响支持代理并继承这些变量的程序。已启动的后台程序不会自动获得新变量。

## 5. watchdog 的运行与保活

watchdog 使用以下参数启动守护进程：

```bash
"$HOME/.local/bin/tailscaled" \
  --tun=userspace-networking \
  --state="$HOME/.local/state/tailscale/tailscaled.state" \
  --socket="$HOME/.local/state/tailscale/tailscaled.sock" \
  --socks5-server=127.0.0.1:1055 \
  --outbound-http-proxy-listen=127.0.0.1:1055
```

原机 watchdog 使用 `while true` 循环。守护进程退出后，watchdog 等待 3 秒再启动守护进程。它使用 `flock` 防止重复启动。

仓库版本保留上述行为。仓库版本要求安装 flock，并使用 `umask 077` 保护新建文件。它确保状态目录的权限为 700。watchdog 结束时，会向自己的守护进程发送 TERM，并等待该进程退出。

如果需要自定义程序目录或状态目录，`ts` 和 watchdog 共同读取 `TAILSCALE_BIN_DIR` 和 `TAILSCALE_STATE_DIR`。通常保留默认值即可。

watchdog 只在守护进程退出后重新启动该进程。它不检测“进程仍存活但无法联网”的情况。它也不自动解决节点密钥过期、访问策略变更或网络故障。

watchdog 本身必须保持运行。服务器未重启，不能保证 Tailscale 始终在线。

使用以下命令检查进程、日志和节点状态：

```bash
ps -u "$USER" -o pid,ppid,args | rg '[t]ailscale-watchdog|[t]ailscaled'
tail -n 50 "$HOME/.local/state/tailscale/tailscaled.log"
"$HOME/.local/bin/ts" status
```

停止服务时，先结束 watchdog。如果只结束 tailscaled，watchdog 会再次启动 tailscaled。

原机旧脚本没有用于结束子进程的 trap。迁移到仓库脚本前，分别确认旧 watchdog 和旧守护进程均已退出。然后启动新 watchdog。

脚本追加写入日志。长期使用时，自行安排日志轮转。

`nohup` 不提供开机自动启动。本次未注册开机服务。服务器重启后，手动启动 watchdog 和 Mihomo。

如果机器允许用户使用 cron，也可用 `crontab -e` 添加以下可选配置：

```cron
@reboot /bin/bash -c 'umask 077; mkdir -p "$HOME/.local/state/tailscale"; exec "$HOME/.local/bin/tailscale-watchdog" >>"$HOME/.local/state/tailscale/watchdog-launch.log" 2>&1'
```

此 cron 配置是部署建议，未在原机安装或验证。不要同时配置其他自动启动来源。

用户 systemd 也可作为替代方式。退出登录后或开机前能否继续运行，取决于机器的 user manager/linger 策略。本方案不要求使用用户 systemd。

## 6. 按顺序验证连接

### 验证节点连接

```bash
ts ping --c=3 --until-direct=false 100.97.69.51
ts ping --icmp --c=3 100.97.69.51
```

第一条命令使用 Tailscale 探测协议确认节点路径。输出 `via DERP(...)` 也表示存在可用路径。第二条命令在 Tailscale 隧道内发送 ICMP。

原机曾通过局域网直连收到 1–2 ms 的响应。原机也收到过成功的 ICMP 响应。普通 `ping` 不能替代这两项测试。[Tailscale ping 类型](https://tailscale.com/docs/reference/ping-types)

### 比较代理访问路径并检查运行配置

```bash
cd "$HOME/Projects/dotfiles"
bash scripts/check-network.sh http://100.97.69.51:8080/
```

如果测试其他服务，将参数替换为该服务的 HTTP(S) 地址。脚本检查 `mode: rule`、Tailscale 代理节点是否存在，以及直连组是否选中 Tailscale。然后，脚本分别通过 1055 和 63796 端口请求服务。Bifrost 根页面的预期响应为 HTTP 200。[Mihomo 控制 API](https://wiki.metacubex.one/api/)

如果 1055 请求成功，但 63796 请求失败，检查 Mihomo 实际使用的配置和连接报错。如果运行时返回 `Tailscale: null` 或 `Resource not found`，则 Mihomo 未加载包含此代理节点的配置。不要仅根据磁盘文件判断运行配置是否生效。

本次 HTTP 502 故障由两个 Mihomo 进程同时运行引起。旧进程使用旧配置，并继续监听 63796/63797 端口。新进程未接管这两个端口。

停止重复实例并明确指定配置后，通过 Mihomo 访问服务成功。因此，新启动脚本同时检查单实例锁和已有监听端口。

本机规则缓存包含 9 条不支持的 `URL-REGEX` 规则：Download 7 条、ProxyMedia 1 条、ChinaMedia 1 条。Mihomo 输出警告并跳过这些规则。其他有效规则继续加载。这些规则不影响本方案的虚拟内网 IP 分流。

如果需要消除警告，更换或修正规则来源。仅修改缓存时，订阅更新会覆盖这些修改。[对应版本的处理逻辑](https://github.com/MetaCubeX/mihomo/blob/v1.19.27/rules/provider/classical_strategy.go#L38)

## 7. 在 macOS 或使用系统原生 Tailscale 的设备上部署

先使用原生 Tailscale 客户端加入虚拟内网。安装对应平台的 Mihomo 客户端或二进制文件。

Linux 安装脚本、watchdog 和 `mihomo-run` 脚本依赖 Linux 环境。不要在 macOS 上直接运行这些脚本。

同步仓库后，可使用以下命令选择原生模式：

```bash
cd "$HOME/Projects/dotfiles"
bash scripts/link-network-dotfiles.sh native
python3 scripts/configure-mihomo.py --profile native
```

按前述方法准备私有订阅文件。`native` 生成器将同名 Tailscale 出口改为 `type: direct`。此模式使用系统已建立的 Tailscale 路由访问虚拟内网。普通公网流量继续使用主机常规网络，无需监听 1055。其余策略组和规则保持一致。

将生成配置导入该设备的 Mihomo 客户端。检查实际代理端口。默认模板使用 63796。

如果客户端使用其他端口，在加载 shell 函数前设置 `MIHOMO_PROXY_PORT`。原生模式只测试通过 Mihomo 发送的服务请求。不要使用包含 1055 端口对比的 `check-network.sh`。

原生模式的配置语法会在本机验证。macOS 客户端导入和实际路由需要在对应设备上验证。

## 8. 日常同步与本次操作范围

修改共享模板或脚本后，提交并推送 dotfiles。在其他机器上拉取更改。各设备继续保留自己的订阅、节点登录状态和缓存。

拉取模板后，重新运行配置生成器。生成器不会自动重载 Mihomo。watchdog 更新后，由用户停止并重新启动 watchdog。

本次只增加仓库文件和文档。原机的脚本链接和运行配置未改变。本次未重载服务、注册 cron 或提交 Git。

原机可继续使用现有路径。准备迁移时，再执行链接、生成配置和启动步骤。

本次已检查脚本和示例命令的语法。两种模式的配置均通过 Mihomo 原生配置解析。私有地址引用、文件权限、备份和重复执行行为均已检查。

临时目录中的模拟进程测试已验证 watchdog 的重启和停止行为。该测试还验证了 Mihomo 单实例锁，以及旧进程占用端口时的启动拦截。新机下载、首次认证和 macOS 客户端导入需要在对应设备上完成。

`~/tailscale-mihomo-setup.md` 是本次部署说明的导出副本。仓库中的 `docs/network-setup.md` 是后续维护的源文件。
