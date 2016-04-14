#!/bin/bash

HOSTS="${HOSTS:-/etc/hosts}"

add_host() {
    local ip="$1" cn="$2"
    local ip_regex="${ip//./\\.}"

    # Remove any existing conflicts
    sed -i '/^'"$ip_regex"'[[:space:]]/d' "$HOSTS"
    sed -i '/[[:space:]]'"$cn"'\([[:space:]]\|$\)/d' "$HOSTS"

    # Add the new entry
    echo -e "${ip}\t${cn}" >> "$HOSTS"

    # Load it into DNS
    /usr/bin/systemctl reload dnsmasq
}

case "$1" in
    'add'|'update')
        add_host "$2" "$3"
        ;;
    'delete')
        # no-op
        ;;
    *)
        echo "Unknown action ${1}" >&2
        exit 1
        ;;
esac
