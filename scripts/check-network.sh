#!/usr/bin/env bash
# Read-only diagnostics for the Linux userspace profile.
set -euo pipefail
if [[ $# != 1 || "$1" == --help ]]; then
    echo "Usage: $0 http://TAILSCALE_IP:SERVICE_PORT/"
    echo "Example: $0 http://100.97.69.51:8080/"
    [[ "${1:-}" == --help ]] && exit 0
    exit 1
fi
for dependency in curl jq; do
    command -v "$dependency" >/dev/null || { echo "Missing dependency: $dependency" >&2; exit 1; }
done
url="$1"
controller=http://127.0.0.1:63797
configs=$(curl -fsS --noproxy '*' --max-time 5 "$controller/configs")
proxies=$(curl -fsS --noproxy '*' --max-time 5 "$controller/proxies")
printf '%s\n' "$configs" | jq '{mode}'
printf '%s\n' "$proxies" | jq '.proxies | {Tailscale: (.Tailscale | if . == null then null else {name,type} end), direct: (."🎯 全球直连" | {now,all})}'
if ! printf '%s\n' "$proxies" | jq -e '.proxies.Tailscale != null' >/dev/null; then
    echo "Running Mihomo has no Tailscale node. Check its PID/config path before retesting." >&2
    exit 1
fi
result=0
if ! printf '%s\n' "$configs" | jq -e '.mode == "rule"' >/dev/null ||
   ! printf '%s\n' "$proxies" | jq -e '.proxies."🎯 全球直连".now == "Tailscale"' >/dev/null; then
    echo "Expected rule mode and the direct group selecting Tailscale." >&2
    result=1
fi
for proxy_url in socks5h://127.0.0.1:1055 http://127.0.0.1:63796; do
    printf 'Testing through %s\n' "$proxy_url"
    if ! curl -fsS --noproxy '' --proxy "$proxy_url" \
        --connect-timeout 5 --max-time 10 -o /dev/null \
        -w 'HTTP %{http_code}\n' "$url"; then
        result=1
    fi
done
exit "$result"
