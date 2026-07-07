#!/bin/bash
key="$1"
value="$(printenv $1)"

if [[ -z $key ]]; then
    exit 0
fi

printf "export %s='%s'\n" "${key}" "${value}" >> /opt/ai-dock/etc/environment.sh
printf "Stored environment variable '%s': %s\n" "$key" "$value"