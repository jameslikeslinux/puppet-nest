#!/bin/bash

HOSTS="${HOSTS:-/etc/hosts}"

delete_host() {
    local ip="$1"
    sed -i '/^'"${ip//./\\.}"'[[:space:]]/d' "$HOSTS"
}

add_host() {
    local ip="$1" cn="$2"
    sed -i '/'"${cn}"'\([[:space:]]\|$\)/d' "$HOSTS"
    echo -e "${ip}\t${cn}" >> "$HOSTS"
}

case "$1" in
    'add'|'update')
        delete_host "$2"
        add_host "$2" "$3"
        ;;
    'delete')
        delete_host "$2"
        ;;
    *)
        echo "${0}: Unknown action ${1}" >&2
        exit 1
        ;;
esac

/usr/bin/systemctl reload dnsmasq
