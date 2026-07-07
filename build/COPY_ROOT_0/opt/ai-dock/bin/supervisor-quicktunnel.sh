#!/bin/bash

trap cleanup EXIT

function cleanup() {
    fuser -k -SIGTERM ${metrics_port:-0}/tcp > /dev/null 2>&1 &
    wait -n
}

function start() {
    source /opt/ai-dock/etc/environment.sh
    
    if [[ -z $PROC_NUM ]]; then
        # Something has gone awry, but no retry
        exec sleep 6
    fi
    
    # Wait for port files to be available (services need time to register)
    # Only consider files that have BOTH proxy_port AND metrics_port
    local max_retries=30
    local retry_count=0
    while [[ $retry_count -lt $max_retries ]]; do
        all_files=(/run/http_ports/*)
        port_files=()
        for f in "${all_files[@]}"; do
            p=$(jq -r .proxy_port "$f" 2>/dev/null)
            m=$(jq -r .metrics_port "$f" 2>/dev/null)
            if [[ -n $p && $p != "null" && -n $m && $m != "null" ]]; then
                port_files+=("$f")
            fi
        done
        if [[ ${#port_files[@]} -gt $PROC_NUM && -f "${port_files[$PROC_NUM]}" ]]; then
            proxy_port=$(jq -r .proxy_port "${port_files[$PROC_NUM]}")
            metrics_port=$(jq -r .metrics_port "${port_files[$PROC_NUM]}")
            if [[ -n $proxy_port && $proxy_port != "null" && -n $metrics_port && $metrics_port != "null" ]]; then
                break
            fi
        fi
        retry_count=$((retry_count + 1))
        sleep 1
    done
    
    if [[ -z $proxy_port || $proxy_port == "null" || -z $metrics_port || $metrics_port == "null" ]]; then
        printf "port not configured after %d retries\n" "$max_retries"
        printf "proxy_port: %s, metrics_port: %s\n" "$proxy_port" "$metrics_port"
        exit 1
    fi
    
    # Tunnel the proxy port so we get authentication
    if [[ ${WEB_ENABLE_HTTPS,,} == true && -f /opt/caddy/tls/container.crt && /opt/caddy/tls/container.key ]]; then
        tunnel="--no-tls-verify --url https://localhost:${proxy_port}"
    else
        tunnel="--url http://localhost:${proxy_port}"
    fi
    
    metrics="--metrics localhost:${metrics_port}"
    
    # Ensure the port is available (kill stale for restart)
    fuser -k -SIGKILL ${metrics_port}/tcp > /dev/null 2>&1 &
    wait -n
    
    cloudflared tunnel ${metrics} ${tunnel}
}

start 2>&1
