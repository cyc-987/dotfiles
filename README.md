# Dotfiles

仓库保存当前使用的 Neovim（LazyVim）和 tmux 个人配置。配置源文件放在仓库里，再用符号链接接入家目录；也可以用 [GNU Stow](https://www.gnu.org/software/stow/manual/stow.html) 管理这些链接。

以下步骤针对 Linux 和 macOS，并使用默认的 `~/.config/nvim` 路径。

## 仓库内容

| 仓库路径 | 安装后的路径 | 说明 |
| --- | --- | --- |
| `nvim/.config/nvim/` | `~/.config/nvim/` | LazyVim 配置，包括 `lazy-lock.json` |
| `tmux/.tmux.conf.local` | `~/.tmux.conf.local` | Oh My Tmux 的个人设置 |

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

先安装 tmux、Neovim 和 [LazyVim 要求的外部工具](https://www.lazyvim.org/)。Oh My Tmux 还需要 awk、perl、grep、sed。Neovim 和 tmux 的版本要求见上面的官方链接。

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

## 当前跨设备限制

`nvim/.config/nvim/lua/plugins/venv-selector.lua` 目前包含本机 Conda 环境目录 `/data/home/cuiyc/Softwares/miniconda3/envs`。在其他设备上，这项环境搜索可能无法正常工作；需要将该路径改为可配置值。这里先原样保存本机配置，后续再处理设备差异。
