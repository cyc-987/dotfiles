# Source this file from ~/.bashrc or ~/.zshrc; it does not enable the proxy itself.
proxy() {
    export http_proxy="http://127.0.0.1:${MIHOMO_PROXY_PORT:-63796}"
    export https_proxy="$http_proxy"
    export all_proxy="socks5h://127.0.0.1:${MIHOMO_PROXY_PORT:-63796}"
    export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy" ALL_PROXY="$all_proxy"
    export no_proxy="localhost,127.0.0.1,::1" NO_PROXY="localhost,127.0.0.1,::1"
    printf 'Proxy enabled: %s\n' "$http_proxy"
}

noproxy() {
    unset http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY
    unset no_proxy NO_PROXY ws_proxy wss_proxy WS_PROXY WSS_PROXY
    printf 'Proxy environment variables unset.\n'
}
