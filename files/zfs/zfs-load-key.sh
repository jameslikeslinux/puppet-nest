#!/bin/sh

# only run this on systemd systems, we handle the decrypt in mount-zfs.sh in the mount hook otherwise
[ -e /bin/systemctl ] || return 0

# This script only gets executed on systemd systems, see mount-zfs.sh for non-systemd systems

# import the libs now that we know the pool imported
[ -f /lib/dracut-lib.sh ] && dracutlib=/lib/dracut-lib.sh
[ -f /usr/lib/dracut/modules.d/99base/dracut-lib.sh ] && dracutlib=/usr/lib/dracut/modules.d/99base/dracut-lib.sh
# shellcheck source=./lib-zfs.sh.in
. "$dracutlib"

# load the kernel command line vars
[ -z "$root" ] && root="$(getarg root=)"
# If root is not ZFS= or zfs: or rootfstype is not zfs then we are not supposed to handle it.
[ "${root##zfs:}" = "${root}" ] && [ "${root##ZFS=}" = "${root}" ] && [ "$rootfstype" != "zfs" ] && exit 0

# There is a race between the zpool import and the pre-mount hooks, so we wait for a pool to be imported
while true; do
    zpool list -H 2>/dev/null | grep -q -v '^$' && break
    [ "$(systemctl is-failed zfs-import-cache.service)" = 'failed' ] && exit 1
    [ "$(systemctl is-failed zfs-import-scan.service)" = 'failed' ] && exit 1
    sleep 0.1s
done

# run this after import as zfs-import-cache/scan service is confirmed good
if [ "${root}" = "zfs:AUTO" ] ; then
    root="$(zpool list -H -o bootfs | awk '$1 != "-" {print; exit}')"
else
    root="${root##zfs:}"
    root="${root##ZFS=}"
fi

# if pool encryption is active and the zfs command understands '-o encryption'
if [ "$(zpool list -H -o feature@encryption $(echo "${root}" | awk -F\/ '{print $1}'))" = 'active' ]; then
    # if the root dataset has encryption enabled
    ENCRYPTIONROOT=$(zfs get -H -o value encryptionroot "${root}")
    if ! [ "${ENCRYPTIONROOT}" = "-" ]; then
        KEYFORMAT=$(zfs get -H -o value keyformat "${root}")
        if [ "${KEYFORMAT}" = "passphrase" ]; then
            # decrypt them
            TRY_COUNT=5
            while [ $TRY_COUNT -gt 0 ]; do
                systemd-ask-password "Encrypted ZFS password for ${root}" --no-tty | zfs load-key "${ENCRYPTIONROOT}" && break
                TRY_COUNT=$((TRY_COUNT - 1))
            done
        else
            zfs load-key "${ENCRYPTIONROOT}"
        fi
    fi
fi
