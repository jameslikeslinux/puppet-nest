#!/bin/zsh
#
# ZFS Boot Environment Manager
#
# Provide functionality similar to beadm(1M) in Solaris 11 with basic support
# for creating, deleting, mounting, and activating boot environments on Linux.
#

usage() {
    cat >&2 <<END_USAGE
Usage: beadm COMMAND [options]

Commands:
  create        Clone the current boot environment to a new one
  mount         Mount a boot environment under /mnt
  activate      Enable the current boot environment for mounting at boot
  destroy       Delete the specified boot environment

END_USAGE
}

usage_basic_cmd() {
    cat >&2 <<END_USAGE
Usage: beadm $1 NAME
END_USAGE
}

current_be() {
    local root="$(findmnt -n -o SOURCE /)"

    if ! zfs list "$root" > /dev/null 2>&1; then
        print '/ is not a ZFS filesystem' >&2
        exit 1
    fi

    print "$root"
}

be_root() {
    local root="$(dirname "$1")"

    if [[ $root != */ROOT ]]; then
        print "${1} is not a boot environment"
        exit 1
    fi

    print "$root"
}

cmd_create() {
    local name="$1" current_be be_root new_be snapshot fs new_fs mountpoint

    if [[ -z $name ]]; then
        usage_basic_cmd create
        exit 1
    fi

    current_be="$(current_be)"
    be_root="$(be_root "$current_be")"
    new_be="${be_root}/${name}"
    snapshot="beadm-clone-$(basename "$current_be")-to-${name}"

    print "Creating ${new_be} from ${current_be}"

    if ! zfs snapshot -r "${current_be}@${snapshot}" > /dev/null 2>&1; then
        print 'Failed to create snapshots for cloning' >&2
        exit 1
    fi

    zfs list -H -o name,mountpoint -r "$current_be" | while read fs mountpoint; do
        new_fs="${new_be}${fs#${current_be}}"

        if ! zfs clone -o canmount=noauto -o mountpoint="$mountpoint" "${fs}@${snapshot}" "$new_fs" > /dev/null 2>&1; then
            print 'Failed to clone snapshot' >&2
            exit 1
        fi
    done
}

cmd_mount() {
    local name="$1" current_be be_root mount_be fs mountpoint

    if [[ -z $name ]]; then
        usage_basic_cmd mount
        exit 1
    fi

    current_be="$(current_be)"
    be_root="$(be_root "$current_be")"
    mount_be="${be_root}/${name}"

    if [[ $mount_be == $current_be ]]; then
        print 'Cannot mount the active boot environment' >&2
        exit 1
    fi

    if ! mkdir -p "/mnt/${name}" > /dev/null 2>&1; then
        print "Failed to create /mnt/${name}" >&2
        exit 1
    fi

    zfs list -H -o name,mountpoint -r "$mount_be" | while read fs mountpoint; do
        print "Mounting ${fs} to /mnt/${name}${mountpoint}"
        if ! mount -t zfs -o zfsutil "$fs" "/mnt/${name}${mountpoint}" > /dev/null 2>&1; then
            print "Failed to mount ${fs}" >&2
            exit 1
        fi
    done
}

cmd_activate() {
    local current_be be_root fs

    current_be="$(current_be)"
    be_root="$(be_root "$current_be")"

    zfs list -H -o name -r "$be_root" | while read fs; do
        if [[ $fs == $current_be* ]]; then
            if ! zfs set canmount=on "$fs" > /dev/null 2>&1; then
                print 'Failed to enable active boot environment' >&2
                exit 1
            fi

            if ! zfs promote "$fs" > /dev/null 2>&1; then
                print 'Failed to promote active boot environment clone' >&2
                exit 1
            fi
        else
            if ! zfs set canmount=noauto "$fs" > /dev/null 2>&1; then
                print 'Failed to disable inactive boot environment' >&2
                exit 1
            fi
        fi
    done
}

cmd_destroy() {
    local name="$1" current_be be_root destroy_be snapshot

    if [[ -z $name ]]; then
        usage_basic_cmd destroy
        exit 1
    fi

    current_be="$(current_be)"
    be_root="$(be_root "$current_be")"
    destroy_be="${be_root}/${name}"

    if [[ $destroy_be == $current_be ]]; then
        print 'Cannot destroy active boot environment' >&2
        exit 1
    fi

    print "Destroying ${destroy_be}"

    if ! zfs destroy -r "$destroy_be" > /dev/null 2>&1; then
        print 'Failed to destroy boot environment' >&2
        exit 1
    fi

    zfs list -H -o name -t snapshot -r "$be_root" | while read snapshot; do
        if [[ $snapshot == *@beadm-clone-$name-to-* || $snapshot == *@beadm-clone-*-to-$name ]]; then
            if ! zfs destroy "$snapshot" > /dev/null 2>&1; then
                print 'Failed to destroy snapshot' >&2
                exit 1
            fi
        fi
    done
}

case "$1" in
    'create'|'mount'|'activate'|'destroy')
        cmd="$1"; shift
        "cmd_${cmd}" "$@"
        ;;

    '-h'|'--help')
        usage
        exit 0
        ;;

    *)
        usage
        exit 1
        ;;
esac
