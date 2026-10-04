#!/usr/bin/env bash
# Backup and link repository files; never modify active Mihomo config or services.
set -euo pipefail
umask 077
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
target_home="${DOTFILES_TARGET_HOME:-$HOME}"
case "${1:-userspace}" in
    userspace) packages=(tailscale mihomo shell) ;;
    native) packages=(shell) ;;
    --help) echo "Usage: $0 [userspace|native] (native only links shell helpers)"; exit 0 ;;
    *) echo "Choose userspace or native." >&2; exit 1 ;;
esac
if [[ "${packages[0]}" == tailscale && $(uname -s) != Linux ]]; then
    echo "Use the native profile on macOS; see docs/network-setup.md." >&2
    exit 1
fi
backup_dir="$target_home/.local/share/dotfiles-backups/network-$(date +%Y%m%d-%H%M%S)-$$"
for package in "${packages[@]}"; do
    while IFS= read -r -d '' source; do
        relative="${source#"$root/$package/"}"
        target="$target_home/$relative"
        if [[ -e "$target" && "$target" -ef "$source" ]] ||
           [[ -L "$target" && $(readlink "$target") == "$source" ]]; then
            printf 'Already linked: %s\n' "$target"
            continue
        fi
        mkdir -p "$(dirname "$target")"
        if [[ -e "$target" || -L "$target" ]]; then
            mkdir -p "$backup_dir/$(dirname "$relative")"
            mv "$target" "$backup_dir/$relative"
            printf 'Backup: %s\n' "$backup_dir/$relative"
        fi
        ln -s "$source" "$target"
        printf 'Linked: %s\n' "$target"
    done < <(find "$root/$package" -type f -print0)
done
echo "Source ~/.config/shell/network-proxy.sh in your shell startup file to use proxy/noproxy."
