#!/bin/false

# This file will be sourced in init.sh
# Fallback: creates VS Code settings.json if supervisor script didn't

function preflight_main() {
    preflight_configure_vscode
}

function preflight_configure_vscode() {
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
        printf "Created VS Code settings.json from preflight (fallback)\n"
    else
        printf "VS Code settings.json already exists, skipping\n"
    fi
}

preflight_main "$@"
