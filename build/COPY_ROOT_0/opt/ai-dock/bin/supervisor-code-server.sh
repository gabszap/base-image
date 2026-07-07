#!/bin/bash

trap cleanup EXIT

LISTEN_PORT=22222
PROXY_PORT="${CODE_SERVER_PROXY_PORT:-2222}"
METRICS_PORT="${CODE_SERVER_METRICS_PORT:-28284}"
SERVICE_NAME="VS Code Server"
SERVICE_URL="${CODE_SERVER_URL:-}"
QUICKTUNNELS=true

function cleanup() {
    rm /run/http_ports/$PROXY_PORT > /dev/null 2>&1
    fuser -k -SIGTERM ${LISTEN_PORT}/tcp > /dev/null 2>&1 &
    wait -n
}

function setup_settings() {
    local settings_dir="/home/${USER_NAME}/.local/share/code-server/User"
    local settings_file="${settings_dir}/settings.json"

    mkdir -p "$settings_dir"

    if [[ ! -f "$settings_file" ]]; then
        cat > "$settings_file" << 'EOF'
{
    "workbench.colorTheme": "Dark 2026",
    "chat.disableAIFeatures": true,
    "window.menuBarVisibility": "classic",
    "symbols.hidesExplorerArrows": true,
    "workbench.iconTheme": "symbols",
    "editor.minimap.enabled": false,
    "workbench.secondarySideBar.defaultVisibility": "hidden",
    "telemetry.telemetryLevel": "off",
    "telemetry.feedback.enabled": false
}
EOF
        chown -R "${USER_NAME}:" "/home/${USER_NAME}/.local"
        printf "Created VS Code settings.json\n"
    else
        printf "VS Code settings.json already exists, skipping\n"
    fi
}

function start() {
    source /opt/ai-dock/etc/environment.sh
    source /opt/ai-dock/bin/venv-set.sh serviceportal

    file_content="$(
      jq --null-input \
        --arg listen_port "${LISTEN_PORT}" \
        --arg metrics_port "${METRICS_PORT}" \
        --arg proxy_port "${PROXY_PORT}" \
        --arg service_name "${SERVICE_NAME}" \
        --arg service_url "${SERVICE_URL}" \
        '$ARGS.named'
    )"

    printf "%s\n" "$file_content" > /run/http_ports/$PROXY_PORT

    printf "Starting ${SERVICE_NAME}...\n"

    fuser -k -SIGKILL ${LISTEN_PORT}/tcp > /dev/null 2>&1 &
    wait -n

    # Use the web password as fallback for code-server password
    if [[ -n $CODE_SERVER_PASSWORD ]]; then
        export PASSWORD="$CODE_SERVER_PASSWORD"
    elif [[ -n $WEB_PASSWORD ]]; then
        export PASSWORD="$WEB_PASSWORD"
    fi

    # Install extensions if configured
    if [[ -n $CODE_SERVER_EXTENSIONS ]]; then
        IFS=',' read -ra EXTENSIONS <<< "$CODE_SERVER_EXTENSIONS"
        for ext in "${EXTENSIONS[@]}"; do
            code-server --install-extension "$(echo "$ext" | xargs)" 2>&1
        done
    fi

    # Create VS Code settings.json before code-server starts
    setup_settings

    # Disable telemetry and getting started
    export DO_NOT_TRACK=1

    code-server \
        --bind-addr "127.0.0.1:${LISTEN_PORT}" \
        --auth password \
        --open /workspace \
        --disable-telemetry \
        --disable-getting-started-override \
        --disable-workspace-trust
}

start 2>&1
