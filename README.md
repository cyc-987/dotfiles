# Dotfiles

仓库保存 Neovim（LazyVim）、tmux，以及 Mihomo 与 Tailscale 配合使用的配置和脚本。配置源文件放在仓库里，再用符号链接接入家目录；也可以用 [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html) 管理这些链接。Mihomo 的私有订阅地址留在本机，由模板生成运行配置。

以下步骤针对 Linux 和 macOS，并使用默认的 `~/.config/nvim` 路径。

## 仓库内容

| 仓库路径 | 安装后的路径 | 说明 |
| --- | --- | --- |
| `nvim/.config/nvim/` | `~/.config/nvim/` | LazyVim 配置，包括 `lazy-lock.json` |
| `tmux/.tmux.conf.local` | `~/.tmux.conf.local` | Oh My Tmux 的个人设置 |
| `tailscale/.local/bin/` | `~/.local/bin/` | Linux 用户态 Tailscale 的 `ts` 和 watchdog |
| `mihomo/.config/mihomo/config.yaml.template` | `~/.config/mihomo/config.yaml.template` | 分流模板；结合本机订阅生成 `config.yaml` |
| `mihomo/.local/bin/mihomo-run` | `~/.local/bin/mihomo-run` | Linux 单实例启动，显式指定配置与数据目录 |
| `shell/.config/shell/network-proxy.sh` | `~/.config/shell/network-proxy.sh` | Bash/zsh 的 `proxy`、`noproxy` |
| `scripts/`、`docs/network-setup.md` | 在仓库内使用 | 网络工具安装、链接、配置生成、检查和部署说明 |

Oh My Tmux 主配置来自它自己的上游仓库 `~/.tmux`，`~/.tmux.conf` 指向 `~/.tmux/.tmux.conf`。

LazyVim 的插件由 `lazy.nvim` 安装，`~/.local/share/nvim`、`~/.local/state/nvim` 和 `~/.cache/nvim` 也不纳入同步。

## 依赖

- Git、tmux、Neovim。选择 Stow 安装方式时还需 GNU Stow。
- [Oh My Tmux](https://github.com/gpakosz/.tmux) 当前要求 tmux ≥ 2.6，以及 awk、perl、grep、sed。
- [LazyVim](https://www.lazyvim.org/) 的 Neovim 版本和外部工具要求可能更新；安装前查看其[当前要求](https://www.lazyvim.org/)。常用功能还依赖 Git、curl、C 编译器、tree-sitter-cli、ripgrep、fd 等工具。

## 新设备安装

### 1. 克隆仓库

将本仓库克隆到任意固定位置。下面以 `~/Projects/dotfiles` 为例，使用仓库当前的 SSH remote：

```sh
mkdir -p "$HOME/Projects"
git clone git@github.com:cyc-987/dotfiles.git "$HOME/Projects/dotfiles"
DOTFILES_DIR="$HOME/Projects/dotfiles"
```

### 2. 安装上游配置所需的软件

先安装 tmux、Neovim 和 [LazyVim 要求的外部工具](https://www.lazyvim.org/)。Oh My Tmux 还需要 awk、perl、grep、sed。Neovim 和 tmux 的版本要求见上面的官方链接。在已有 Neovim 的设备上，可以跳过下面的无 sudo 安装步骤。

#### 无 sudo 的 Linux 服务器：安装 Neovim

根据 [Neovim 官方安装说明](https://github.com/neovim/neovim/blob/master/INSTALL.md#linux)，可以将预编译压缩包安装在自己的家目录。下面的命令支持 `x86_64` 和 `aarch64`/`arm64`；需要 `curl` 和 `tar`，且服务器能够访问 GitHub：

```sh
case "$(uname -m)" in
  x86_64) nvim_arch=x86_64 ;;
  aarch64|arm64) nvim_arch=arm64 ;;
  *) echo "请先确认该服务器是否有对应的 Neovim 发行包" >&2; exit 1 ;;
esac

mkdir -p "$HOME/.local/opt" "$HOME/.local/bin"
curl -fL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${nvim_arch}.tar.gz" \
  -o "$HOME/.local/opt/nvim-linux-${nvim_arch}.tar.gz"
tar -xzf "$HOME/.local/opt/nvim-linux-${nvim_arch}.tar.gz" -C "$HOME/.local/opt"
ln -s "$HOME/.local/opt/nvim-linux-${nvim_arch}/bin/nvim" "$HOME/.local/bin/nvim"
export PATH="$HOME/.local/bin:$PATH"
nvim --version
```

若 `~/.local/bin/nvim` 已存在，先确认来源并备份，再建立链接。将 `export PATH="$HOME/.local/bin:$PATH"` 加入服务器使用的 shell 启动文件（例如 `~/.bashrc` 或 `~/.zshrc`），这样重新登录后仍能运行 `nvim`。如果服务器无法访问 GitHub，可在其他机器下载相同架构的官方压缩包，传到服务器后从 `tar` 命令继续。

此处安装的是 Neovim 程序本身；第 3 步会链接个人配置，首次启动时再由 `lazy.nvim` 安装 LazyVim 插件。运行 `:LazyHealth` 可以检查服务器缺少的外部工具；这些工具需按服务器环境单独准备。

#### Oh My Tmux

按 [Oh My Tmux 官方手动安装方式](https://github.com/gpakosz/.tmux#installation)克隆上游仓库。以下两条命令分别只在 `~/.tmux`、`~/.tmux.conf` 不存在时执行。如果本机已经安装 Oh My Tmux，复用现有上游仓库和主配置链接：

```sh
git clone --single-branch https://github.com/gpakosz/.tmux.git "$HOME/.tmux"
ln -s .tmux/.tmux.conf "$HOME/.tmux.conf"
```

如果这些路径已有其他内容，先确认来源并备份，避免覆盖其他 tmux 配置。**不要执行官方安装步骤中复制 `.tmux/.tmux.conf.local` 的命令**；下一步会从本仓库链接个人配置。

#### LazyVim

[LazyVim 官方安装](https://www.lazyvim.org/installation)先运行 `git clone https://github.com/LazyVim/starter ~/.config/nvim`，随后启动 Neovim。本仓库的 `nvim/.config/nvim` 已经包含这个 starter 和个人修改，因此使用本仓库时**不再单独运行这条克隆命令**，直接执行下一节的链接步骤。

首次启动 `nvim` 后，仓库中的 `lua/config/lazy.lua` 会自动从 `folke/lazy.nvim` 安装插件管理器，再由它安装 `LazyVim/LazyVim` 和其余插件。无需提前克隆这些插件仓库，也无需把它们放进本仓库。

### 3. 备份旧配置并建立符号链接

如果目标路径已有文件、目录或旧链接，先备份 `~/.config/nvim` 和 `~/.tmux.conf.local`。本机首次迁移也按此步骤进行；若两个路径已正确指向本仓库，则跳过本节。`DOTFILES_DIR` 使用第 1 步设置的绝对路径。

```sh
mkdir -p "$HOME/.config"
backup_dir="$HOME/.local/share/dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
if [ -e "$HOME/.config/nvim" ] || [ -L "$HOME/.config/nvim" ]; then
  mv "$HOME/.config/nvim" "$backup_dir/nvim"
fi
if [ -e "$HOME/.tmux.conf.local" ] || [ -L "$HOME/.tmux.conf.local" ]; then
  mv "$HOME/.tmux.conf.local" "$backup_dir/tmux.conf.local"
fi
ln -s "$DOTFILES_DIR/nvim/.config/nvim" "$HOME/.config/nvim"
ln -s "$DOTFILES_DIR/tmux/.tmux.conf.local" "$HOME/.tmux.conf.local"
```

确认链接指向本仓库，并保留备份目录：

```sh
ls -ld "$HOME/.config/nvim" "$HOME/.tmux.conf.local" "$HOME/.tmux.conf"
```

也可以在备份旧配置后用 GNU Stow 建立相同的链接。将上面两条 `ln -s` 命令换成以下命令即可，**不要把两种方式同时执行**：

```sh
stow --simulate --verbose --dir "$DOTFILES_DIR" --target "$HOME" nvim tmux
stow --verbose --dir "$DOTFILES_DIR" --target "$HOME" nvim tmux
```

先检查 `--simulate` 的输出。如果它报告冲突，检查对应路径及备份，不要使用 `stow --adopt` 覆盖仓库文件。安装完成后，在 `~/.config/nvim` 和 `~/.tmux.conf.local` 编辑就是修改仓库中的文件。

### 4. 启动应用

启动 `tmux`，或在已有 tmux 会话中执行 `tmux source-file ~/.tmux.conf`。启动 `nvim` 时，配置中的 `lazy.lua` 会自动安装 `lazy.nvim`；随后安装所需插件。要让另一台设备使用 `lazy-lock.json` 记录的插件版本，在 Neovim 中运行 `:Lazy restore`。安装后可运行 `:LazyHealth` 检查依赖和插件状态。详情见 [lazy.nvim 的锁文件说明](https://lazy.folke.io/usage/lockfile)和 [LazyVim 安装说明](https://www.lazyvim.org/installation)。

## 日常同步

在一台设备修改配置后，在本仓库提交并推送；其他设备拉取更新。插件升级导致 `lazy-lock.json` 变化时，也一起提交。Oh My Tmux 上游仓库单独更新，不与此仓库的提交混在一起。

## Mihomo 与 Tailscale

按本节完成网络部署。原机的配置更改、watchdog 保活机制和排障记录见 [网络配置说明](docs/network-setup.md)。只部署网络工具时，无需安装 Neovim 或 tmux。

Linux 用户态方案的访问路径为：应用 → Mihomo `127.0.0.1:63796` → Tailscale SOCKS5 `127.0.0.1:1055` → 虚拟内网服务。公网继续按 Mihomo 规则分流。应用必须使用代理，才能进入这条路径。普通 `ping` 不使用代理。

### Linux：无 sudo 权限的用户态部署

适用架构为 x86_64 和 aarch64/arm64。在同一个 Bash 终端中执行以下步骤。所需工具为 Git、curl、tar、gzip、install、flock、ss 和 Python ≥ 3.8。验证脚本还需要 jq。下面的进程查询需要 rg。

#### 1. 设置仓库路径和程序搜索路径

如果尚未克隆仓库，先执行本 README 的“克隆仓库”步骤。将下面的仓库路径改为实际的固定绝对路径：

```bash
DOTFILES_DIR="$HOME/Projects/dotfiles"
cd "$DOTFILES_DIR"
export PATH="$HOME/.local/bin:$PATH"
```

`DOTFILES_DIR` 是本 README 命令使用的变量。脚本不读取这个变量，无需将它导出。后续命令使用它组成脚本的绝对路径。新开终端后，重新设置此变量。

`PATH` 使当前终端能够找到安装在 `~/.local/bin` 的程序。第 6 步说明如何保存这项设置。

#### 2. 安装程序并链接脚本

运行安装脚本：

```bash
bash "$DOTFILES_DIR/scripts/install-network-tools.sh"
```

脚本默认安装官方最新稳定版，无需设置版本变量。安装包保存在 `~/.local/opt/network-downloads`，程序安装到 `~/.local/bin`。脚本保留已有的可执行程序，并打印实际版本。

如需指定版本，先设置下表中的变量。示例使用原机验证过的版本号，实际设置时选择所需版本。版本号可带 `v` 前缀。每个变量只影响对应程序。已有程序仍会跳过，不会因设置版本变量而自动升级。

| 可选变量 | 默认值 | 设置方式 |
| --- | --- | --- |
| `TAILSCALE_VERSION` | `latest` | 例如 `export TAILSCALE_VERSION=1.102.4` |
| `MIHOMO_VERSION` | `latest` | 例如 `export MIHOMO_VERSION=1.19.27` |

下载命令继承当前终端的代理环境变量。如果下载需要代理，先配置一个可用的代理出口。

安装成功后，运行链接脚本：

```bash
bash "$DOTFILES_DIR/scripts/link-network-dotfiles.sh"
```

链接脚本将同名旧文件备份到 `~/.local/share/dotfiles-backups/network-时间-PID/`，再建立指向仓库的链接。正确的已有链接会保留。安装和链接脚本均不启动服务。

#### 3. 保存订阅并生成 Mihomo 配置

输入完整的代理订阅 URL。输入内容不会回显。真实地址保存在家目录，不写入仓库：

```bash
mkdir -p "$HOME/.config/mihomo"
umask 077
read -r -s -p 'Mihomo 订阅 URL: ' mihomo_subscription_url
printf '\n'
printf '%s\n' "$mihomo_subscription_url" > "$HOME/.config/mihomo/subscription.url"
unset mihomo_subscription_url
chmod 600 "$HOME/.config/mihomo/subscription.url"
python3 "$DOTFILES_DIR/scripts/configure-mihomo.py"
```

生成器从仓库读取模板和本机订阅文件。它生成 `~/.config/mihomo/config.yaml`，文件权限为 600。如果已有配置的内容不同，生成器先备份旧配置。生成器不重载 Mihomo。

#### 4. 启动 Tailscale 并登录虚拟内网

如果本用户已经运行旧 watchdog 或 tailscaled，先确认其启动方式。迁移时，先结束旧 watchdog，再确认旧 tailscaled 已退出。

启动仓库中的 watchdog：

```bash
mkdir -p "$HOME/.local/state/tailscale"
chmod 700 "$HOME/.local/state/tailscale"
nohup "$HOME/.local/bin/tailscale-watchdog" \
  </dev/null >>"$HOME/.local/state/tailscale/watchdog-launch.log" 2>&1 &
```

等待本地控制套接字建立。检查节点状态和日志：

```bash
"$HOME/.local/bin/ts" status
tail -n 30 "$HOME/.local/state/tailscale/tailscaled.log"
```

首次部署时，状态可以提示需要登录。如果守护进程尚未运行，先查看日志。确认启动完成后，执行首次登录命令：

```bash
"$HOME/.local/bin/ts" up \
  --hostname="$(hostname -s)" \
  --accept-routes=false \
  --accept-dns=true \
  --ssh=false
```

打开命令输出的链接，完成认证。每台设备使用自己的节点状态。不要复制其他设备的 `tailscaled.state`。

#### 5. 启动 Mihomo

先查询已有实例和监听端口：

```bash
ss -ltnp | rg ':(63796|63797)\b'
ps -u "$USER" -o pid,ppid,args | rg '[m]ihomo'
```

如果旧实例占用 63796 或 63797，先在其原终端结束该实例。也可对已确认属于本用户的进程执行 `kill -TERM PID`。PID 必须来自当前查询结果。

确认没有旧实例后，在后台启动 Mihomo：

```bash
mkdir -p "$HOME/.local/state/mihomo"
chmod 700 "$HOME/.local/state/mihomo"
nohup "$HOME/.local/bin/mihomo-run" \
  </dev/null >>"$HOME/.local/state/mihomo/mihomo.log" 2>&1 &
```

启动器使用 `~/.config/mihomo/config.yaml` 和 `~/.config/mihomo` 数据目录。它检查单实例锁和监听端口。启动日志为 `~/.local/state/mihomo/mihomo.log`。

如需前台调试，用 `"$HOME/.local/bin/mihomo-run"` 替换上述后台启动命令。两种启动方式只选择一种。

#### 6. 加载终端代理并保存 shell 设置

将下面两行合并到实际使用的 shell 启动文件。Bash 使用 `~/.bashrc`，zsh 使用 `~/.zshrc`。如果已有同名 `proxy` 或 `noproxy` 函数，用仓库版本替换旧定义。

```bash
export PATH="$HOME/.local/bin:$PATH"
[ ! -f "$HOME/.config/shell/network-proxy.sh" ] || . "$HOME/.config/shell/network-proxy.sh"
```

在当前终端加载函数并启用代理：

```bash
. "$HOME/.config/shell/network-proxy.sh"
proxy
```

加载文件只定义函数。运行 `proxy` 才会设置当前终端的代理变量。默认的 HTTP/HTTPS 代理为 `http://127.0.0.1:63796`，ALL_PROXY 为 `socks5h://127.0.0.1:63796`。函数同时设置大写和小写变量。

运行 `noproxy` 清除代理变量。`NO_PROXY` 只包含 localhost、127.0.0.1 和 ::1。不要把虚拟内网的 `100.x` 地址加入绕过列表。

代理变量只影响支持代理且继承这些变量的程序。已启动的程序不会自动获得新变量。

#### 7. 验证节点和服务连接

先检查 Tailscale 节点连接：

```bash
ts ping --c=3 --until-direct=false 100.97.69.51
ts ping --icmp --c=3 100.97.69.51
```

再检查 Mihomo 运行配置，并比较两条代理访问路径：

```bash
bash "$DOTFILES_DIR/scripts/check-network.sh" http://100.97.69.51:8080/
```

上述地址是原机验证过的 Bifrost 服务。测试自己的服务时，替换节点 IP 和 HTTP(S) 服务地址。该服务根页面的预期响应为 HTTP 200。

检查脚本要求 Mihomo 使用规则模式，存在 Tailscale 代理节点，且“全球直连”组选中 Tailscale。脚本分别通过 1055 和 63796 端口请求服务。

`nohup` 不提供开机自动启动。服务器重启后，重新执行第 4 步的 watchdog 启动命令和第 5 步的 Mihomo 启动命令。正常重启复用本机 Tailscale 状态，无需每次重新认证。

### 可选：自定义运行路径和代理端口

上面的部署步骤使用默认路径。以下变量仅在需要自定义位置时设置。在启动服务前，将所需变量导出。下文给出路径设置示例。

| 变量 | 默认值 | 作用 |
| --- | --- | --- |
| `TAILSCALE_BIN_DIR` | `~/.local/bin` | 指定 `ts` 和 watchdog 使用的 Tailscale 程序目录 |
| `TAILSCALE_STATE_DIR` | `~/.local/state/tailscale` | 指定状态、套接字、锁和守护进程日志目录；`ts` 和 watchdog 必须使用同一值 |
| `MIHOMO_BIN` | `~/.local/bin/mihomo` | 指定 `mihomo-run` 使用的可执行文件 |
| `MIHOMO_CONFIG` | `~/.config/mihomo/config.yaml` | 指定 `mihomo-run` 读取的配置文件 |
| `MIHOMO_DATA_DIR` | `~/.config/mihomo` | 指定 Mihomo 数据目录 |
| `MIHOMO_STATE_DIR` | `~/.local/state/mihomo` | 指定 Mihomo 启动锁目录 |
| `MIHOMO_PROXY_PORT` | `63796` | 指定终端代理函数使用的端口；不修改 Mihomo 的配置或监听端口 |

路径变量使用绝对路径，例如 `export MIHOMO_BIN="$HOME/Softwares/mihomo/mihomo"`。启动变量不会改变生成器的输出位置。自定义配置位置时，向生成器传入 `--output`。自定义订阅文件时，传入 `--subscription-file`。

自定义状态目录后，同步调整上述日志重定向和日志查询路径。Linux 用户态启动器仍检查固定的 63796/63797 端口。本节用户态方案保持这两个端口不变。

### macOS 或已有系统原生 Tailscale 的设备

先安装对应平台的 Tailscale 和 Mihomo 客户端。使用原生 Tailscale 客户端加入虚拟内网。配置生成需要 Python ≥ 3.8。

设置实际仓库位置，并只链接终端代理函数：

```bash
DOTFILES_DIR="$HOME/Projects/dotfiles"
cd "$DOTFILES_DIR"
bash "$DOTFILES_DIR/scripts/link-network-dotfiles.sh" native
```

按上面的“保存订阅并生成 Mihomo 配置”步骤保存订阅文件。将该步骤最后一条生成命令替换为：

```bash
python3 "$DOTFILES_DIR/scripts/configure-mihomo.py" --profile native
```

将生成的 `~/.config/mihomo/config.yaml` 导入 Mihomo 客户端。此配置中的 Tailscale 出口为直连，使用系统已经建立的虚拟内网路由。此模式无需启动用户态 watchdog。

按第 6 步加载终端代理函数。核对客户端的实际代理端口。模板默认使用 63796。如果客户端实际使用 7890，在运行 `proxy` 前执行：

```bash
export MIHOMO_PROXY_PORT=7890
```

只检查经过 Mihomo 的服务访问：

```bash
curl -fsS --noproxy '' \
  --proxy "http://127.0.0.1:${MIHOMO_PROXY_PORT:-63796}" \
  --connect-timeout 5 --max-time 10 \
  -o /dev/null -w 'HTTP %{http_code}\n' http://100.97.69.51:8080/
```

测试自己的服务时，替换最后的 HTTP(S) 地址。原生模式不运行依赖 1055 端口的 `check-network.sh`。

### 网络配置的日常同步

拉取模板更新后，按首次部署时选择的模式重新运行生成器。然后自行重载 Mihomo。watchdog 脚本更新后，自行停止并重新启动 watchdog。

Tailscale 登录状态、节点密钥、日志、订阅凭据、Mihomo 缓存和二进制文件留在各设备上，不纳入同步。

## 当前跨设备限制

`nvim/.config/nvim/lua/plugins/venv-selector.lua` 目前包含本机 Conda 环境目录 `/data/home/cuiyc/Softwares/miniconda3/envs`。在其他设备上，这项环境搜索可能无法正常工作；需要将该路径改为可配置值。这里先原样保存本机配置，后续再处理设备差异。
