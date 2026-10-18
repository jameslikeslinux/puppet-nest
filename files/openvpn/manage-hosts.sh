#!/bin/bash

HOSTS="${HOSTS:-/etc/hosts}"

add_host() {
    local ip_regex="${ifconfig_pool_remote_ip//./\\.}"

    # Remove any existing conflicts
    delete_host

    # Add the new entry
    echo -e "${ifconfig_pool_remote_ip}\t${common_name}" >> "$HOSTS"

    # Queue the DNS update without waiting for other service lifecycle jobs.
    /bin/systemctl --no-block reload dnsmasq
}

delete_host() {
    local ip_regex="${ifconfig_pool_remote_ip//./\\.}"

    sed -i '/^'"$ip_regex"'[[:space:]]/d' "$HOSTS"
    sed -i '/[[:space:]]'"$common_name"'\([[:space:]]\|$\)/d' "$HOSTS"

    # Shutdown can already have a dnsmasq stop job queued. Waiting for a reload
    # from OpenVPN's synchronous disconnect hook can block VPN teardown.
    /bin/systemctl --no-block reload dnsmasq
}

case "$0" in
    *client-connect.sh)
        add_host
        ;;
    *client-disconnect.sh)
        delete_host
        ;;
    *)
        echo "Not intended to be called as ${0}" >&2
        exit 1
        ;;
esac
