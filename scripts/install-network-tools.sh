#!/usr/bin/env bash
# Official Linux binaries, installed per machine; never start/reload a service.
set -euo pipefail

if [[ "${1:-}" == --help ]]; then
    echo "Usage: $0 [tailscale|mihomo|all]"
    echo "Defaults: all; latest stable versions of Tailscale and Mihomo."
    echo "Set TAILSCALE_VERSION or MIHOMO_VERSION to a version (optional v prefix) or latest."
    echo "Resolving latest versions requires python3."
    echo "Existing executables are preserved. Linux amd64/arm64 only."
    exit 0
fi
component="${1:-all}"
case "$component" in tailscale|mihomo|all) ;; *) echo "Unknown component: $component" >&2; exit 1 ;; esac
[[ $(uname -s) == Linux ]] || { echo "Use native installers on macOS; see docs/network-setup.md." >&2; exit 1; }
case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *) echo "Unsupported architecture: $(uname -m)" >&2; exit 1 ;;
esac
for dependency in curl tar gzip install; do
    command -v "$dependency" >/dev/null || { echo "Missing dependency: $dependency" >&2; exit 1; }
done
tailscale_version="${TAILSCALE_VERSION:-latest}"
mihomo_version="${MIHOMO_VERSION:-latest}"

resolve_version() {
    local tool="$1" version="$2" metadata_url metadata
    if [[ "$version" == latest ]]; then
        command -v python3 >/dev/null || { echo "Resolving latest versions requires python3." >&2; return 1; }
        case "$tool" in
            tailscale) metadata_url='https://pkgs.tailscale.com/stable/?mode=json&os=linux' ;;
            mihomo) metadata_url='https://api.github.com/repos/MetaCubeX/mihomo/releases/latest' ;;
        esac
        if ! metadata=$(curl -fsSL --retry 2 --connect-timeout 10 --max-time 30 "$metadata_url"); then
            echo "Cannot fetch latest stable $tool version; set its version variable to use a specific release." >&2
            return 1
        fi
        if ! version=$(python3 -c '
import json
import sys

tool = sys.argv[1]
try:
    metadata = json.load(sys.stdin)
    if tool == "tailscale":
        version = metadata["TarballsVersion"]
    else:
        if metadata.get("draft") or metadata.get("prerelease"):
            raise ValueError("release is a draft or prerelease")
        version = metadata["tag_name"]
    if not isinstance(version, str) or not version:
        raise ValueError("version is missing or invalid")
except (KeyError, TypeError, ValueError, AttributeError) as error:
    print(f"Cannot read latest stable {tool} version: {error}", file=sys.stderr)
    sys.exit(1)
print(version)
' "$tool" <<< "$metadata"); then
            return 1
        fi
    fi
    version="${version#v}"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid $tool version; use latest or a release version such as 1.2.3." >&2; return 1; }
    printf '%s\n' "$version"
}

bin_dir="$HOME/.local/bin"
download_dir="$HOME/.local/opt/network-downloads"
mkdir -p "$bin_dir" "$download_dir"

if [[ "$component" == tailscale || "$component" == all ]]; then
    if [[ -x "$bin_dir/tailscale" && -x "$bin_dir/tailscaled" ]]; then
        echo "Preserving existing tailscale/tailscaled binaries."
    elif [[ -e "$bin_dir/tailscale" || -L "$bin_dir/tailscale" || -e "$bin_dir/tailscaled" || -L "$bin_dir/tailscaled" ]]; then
        echo "Incomplete existing Tailscale installation; inspect both binaries before replacing them." >&2
        exit 1
    else
        tailscale_version=$(resolve_version tailscale "$tailscale_version")
        echo "Installing Tailscale $tailscale_version ($arch)."
        name="tailscale_${tailscale_version}_${arch}"
        archive="$download_dir/$name.tgz"
        curl -fL --retry 2 "https://dl.tailscale.com/stable/$name.tgz" -o "$archive"
        tar -xzf "$archive" -C "$download_dir"
        install -m 755 "$download_dir/$name/tailscale" "$bin_dir/tailscale"
        install -m 755 "$download_dir/$name/tailscaled" "$bin_dir/tailscaled"
    fi
    "$bin_dir/tailscale" version
fi
if [[ "$component" == mihomo || "$component" == all ]]; then
    if [[ -x "$bin_dir/mihomo" ]]; then
        echo "Preserving existing Mihomo binary."
    elif [[ -e "$bin_dir/mihomo" || -L "$bin_dir/mihomo" ]]; then
        echo "Existing $bin_dir/mihomo is not executable; inspect it first." >&2
        exit 1
    else
        mihomo_version=$(resolve_version mihomo "$mihomo_version")
        echo "Installing Mihomo $mihomo_version ($arch)."
        mihomo_arch="$arch"
        [[ "$arch" != amd64 ]] || mihomo_arch=amd64-v1
        asset="mihomo-linux-${mihomo_arch}-v${mihomo_version}.gz"
        archive="$download_dir/$asset"
        curl -fL --retry 2 "https://github.com/MetaCubeX/mihomo/releases/download/v${mihomo_version}/$asset" -o "$archive"
        gzip -dc "$archive" > "$download_dir/mihomo"
        install -m 755 "$download_dir/mihomo" "$bin_dir/mihomo"
    fi
    "$bin_dir/mihomo" -v
fi
