#!/bin/bash
#
# Nest Installer
#


usage() {
    cat >&2 <<END
Usage: nest-install [options] [NAME]

Options:
  -d, --disk DEVICE     the disk to format and install on
  -e, --encrypt         encrypt the resulting pool
  -n, --dry-run         just print out what would be done
  --partition-only      just partition/format the disk and exit
  --resume              mount and resume install at image copy stage
  --shell               mount and launch a debug shell inside the chroot
  --help                display this message and exit
END
}

if ! args=$(getopt -o "ed:n" -l "encrypt,disk:,dry-run,partition-only,resume,shell,help" -n nest-install -- "$@"); then
    usage
    exit 1
fi

eval set -- "$args"

while true; do
    case $1 in
        -d|--disk)
            shift
            disk="$1"
            shift
            ;;
        -e|--encrypt)
            shift
            encrypt=1
            ;;
        -n|--dry-run)
            shift
            dryrun=1
            ;;
        --partition-only)
            shift
            partition_only=1
            ;;
        --resume)
            shift
            resume=1
            ;;
        --shell)
            shift
            resume=1
            shell=1
            ;;
        --help)
            shift
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "Must be run as root" >&2
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "Must specify a name" >&2
    usage
    exit 1
fi

name="$1"
img="/nest/hosts/${name}"
target="/mnt/${name}"

if [[ ! -d $img ]]; then
    echo "Stage 3 image at ${img} does not exist" >&2
    exit 1
fi

if profile="$(readlink -f "${img}/etc/portage/make.profile")"; then
    platform="${profile%/*}"
    platform="${platform##*/}"
    role="${profile##*/}"
fi

if [[ $platform == 'live' ]]; then
    if [[ $encrypt ]]; then
        echo "Live images cannot be encrypted" >&2
        exit 1
    fi

    disk="${disk:-${name}.iso}"
fi

if [[ -z $disk ]]; then
    echo "Must specify a disk" >&2
    usage
    exit 1
fi


cleanup() {
    task "Cleaning up..."

    # Unmount if necessary
    mountpoint -q "$target" && fallable_cmd umount -R "$target"

    # Remove mountpoint if necessary
    if [[ -e $target ]] && [[ ! "$(ls -A "$target")" ]]; then
        fallable_cmd rm -rf "$target"
    fi

    # Export pool filesystem if necessary
    zpool list "$name" > /dev/null 2>&1 && fallable_cmd zpool export "$name"

    trap - EXIT
}

task() {
    echo
    echo "$@"
}

fallable_cmd() {
    echo "> $@"
    if [[ ! $dryrun ]]; then
        "$@"
    fi
}

cmd() {
    if ! fallable_cmd "$@"; then
        echo "FAILED"
        exit 1
    fi
}

destructive_cmd() {
    [[ $resume ]] || cmd "$@"
}

nspawn() {
    local -a bindargs

    for arch in aarch64 arm; do
        if [[ -f "/usr/bin/qemu-${arch}" ]]; then
            bindargs+=("--bind-ro=/usr/bin/qemu-${arch}")
        fi
    done

    systemd-nspawn "${bindargs[@]}" "$@"
}

chroot_cmd() {
    echo ">> $@"
    if [[ ! $dryrun ]]; then
        if ! nspawn --console=pipe -q --bind=/dev --bind=/nest --capability=all --property='DeviceAllow=block-* rwm' -D "$target" "$@"; then
            echo "FAILED"
            exit 1
        fi
    fi
}

destructive_chroot_cmd() {
    [[ $resume ]] || chroot_cmd "$@"
}

make_dir() {
    [[ -d $1 ]] || cmd mkdir -p "$1"
}

chroot_make_dir() {
    [[ -d "${target}${1}" ]] || chroot_cmd mkdir -p "$1"
}

zroot="$name"

if [[ $encrypt ]]; then
    echo -n "Encryption passphrase: "
    read -s enc_passphrase
    echo

    if [[ ! $resume ]]; then
        echo -n "Encryption passphrase (again): "
        read -s enc_passphrase_repeat
        echo

        if [ "$enc_passphrase" != "$enc_passphrase_repeat" ]; then
            echo "The passphrases don't match." >&2
            exit 1
        fi
    fi

    zroot="${name}/crypt"
    echo
fi


trap cleanup EXIT
echo "Making build target..."
make_dir "$target"


if [[ $platform == 'live' ]]; then
    live_dir="/var/tmp/${name}"

    task "Making live CD directory structure..."
    make_dir "${live_dir}/LiveOS/squashfs-root/LiveOS"

    task "Making live CD root image..."
    destructive_cmd truncate -s 20G "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img"
    destructive_cmd mkfs.ext4 "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img"
    destructive_cmd tune2fs -o discard "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img"

    task "Mounting image at build target..."
    cmd mount "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img" "$target"
else
    task "Partitioning ${disk}..."

    if [[ $platform == 'sopine' ]]; then
        gpt_table_length='table-length: 56'
    fi

    if [[ ! -d /sys/firmware/efi ]]; then
        # The hopefully-rare exception
        destructive_cmd sfdisk "$disk" <<END
label: gpt
$gpt_table_length
size=30720, type=21686148-6449-6E6F-744E-656564454649, name="${name}-bios"
size=512MiB, type=BC13C2FF-59E6-4262-A352-B275FD6F7172, name="${name}-boot"
name="${name}"
END
    else
        destructive_cmd sfdisk "$disk" <<END
label: gpt
$gpt_table_length
start=32768, size=512MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="${name}-boot"
name="${name}"
END
    fi

    destructive_cmd udevadm settle

    if [[ $resume ]]; then
        task "Importing ZFS pool..."
        cmd zpool import -f -R "$target" "$name"
        [[ $encrypt ]] && cmd zfs load-key -r -L prompt "$zroot" <<< "$enc_passphrase"
        cmd zfs mount -a
    else
        task "Creating ZFS pool..."
        destructive_cmd zpool create -f -m none -o ashift=9 -O compression=lz4 -O xattr=sa -O acltype=posixacl -R "$target" "$name" "$name"
        [[ $encrypt ]] && destructive_cmd zfs create -o encryption=aes-128-gcm -o keyformat=passphrase -o keylocation=prompt "$zroot" <<< "$enc_passphrase"
        destructive_cmd zfs create "${zroot}/ROOT"
        destructive_cmd zfs create -o mountpoint=/ "${zroot}/ROOT/a"
        destructive_cmd zfs create -o mountpoint=/var "${zroot}/ROOT/a/var"
        destructive_cmd zfs create -o mountpoint=/usr/lib/debug -o compression=zstd "${zroot}/ROOT/a/debug"
        destructive_cmd zfs create -o mountpoint=/usr/src -o compression=zstd "${zroot}/src"
        destructive_cmd zfs create -o mountpoint=/home "${zroot}/home"
        destructive_cmd zfs create "${zroot}/home/james"
        destructive_cmd zpool set bootfs="${zroot}/ROOT/a" "$name"
    fi

    task "Creating swap space..."

    case "$platform" in
        'beagleboneblack')
            swap_size='1536M'
            ;;
        'pinebookpro'|'raspberrypi')
            swap_size='8G'
            ;;
        *)
            swap_size='4G'
            ;;
    esac


    if [[ $name =~ ([0-9]+)$ ]]; then
        suffix="${BASH_REMATCH[1]}"
    fi

    if (( ${#name} > 8 )); then
        labelname="${name:0:$((8 - ${#suffix}))}${suffix}"
    else
        labelname="$name"
    fi

    destructive_cmd zfs create -V "$swap_size" -b 4096 -o refreservation=none "${zroot}/swap"
    destructive_cmd udevadm settle
    destructive_cmd mkswap -L "${labelname}-swap" "/dev/zvol/${zroot}/swap"

    if grep "${labelname}-fscache" "${img}/etc/fstab" > /dev/null; then
        task "Creating fscache..."
        destructive_cmd zfs create -V 2G "${zroot}/fscache"
        destructive_cmd udevadm settle
        destructive_cmd mkfs.ext4 -L "${labelname}-fscache" "/dev/zvol/${zroot}/fscache"
        destructive_cmd tune2fs -o discard "/dev/zvol/${zroot}/fscache"
    fi

    task "Creating boot filesystem..."
    destructive_cmd mkfs.vfat "/dev/disk/by-partlabel/${name}-boot"
    make_dir "${target}/boot"
    cmd mount PARTLABEL="${name}-boot" "${target}/boot"
fi

[[ $partition_only ]] && exit

if [[ $shell ]]; then
    # This is inteneded for debugging a failed installation
    # Not really meant for recovering established images
    task "Launching debug shell..."
    nspawn --console=interactive -q -E TERM="$TERM" --bind=/nest --capability=all -D "$target" zsh
    exit
fi

task "Copying image..."
cmd rsync --archive --delete --hard-links --info=progress2 "root@falcon:${img}/" "$target"

task "Installing bootloader..."
chroot_cmd puppet agent --onetime --verbose --no-daemonize --no-splay --show_diff --tags nest::base::bootloader

case "$platform" in
    'beagleboneblack')
        cmd dd if="${img}/usr/src/u-boot/MLO" of="$disk" seek=256
        cmd dd if="${img}/usr/src/u-boot/u-boot.img" of="$disk" seek=768
        ;;

    'pinebookpro')
        cmd dd if="${img}/usr/src/u-boot/idbloader.img" of="$disk" seek=64
        cmd dd if="${img}/usr/src/u-boot/u-boot.itb" of="$disk" seek=16384
        ;;

    'sopine')
        cmd dd if="${img}/usr/src/u-boot/u-boot-sunxi-with-spl.bin" of="$disk" seek=16
        ;;

    'live')
        iso_label=$(echo "$name" | tr 'a-z' 'A-Z')

        task "Configuring live CD boot..."
        make_dir "${live_dir}/boot"
        cmd mv "${target}/boot/"* "${live_dir}/boot/"

        cleanup

        task "Making squashfs.img..."
        cmd mksquashfs "${live_dir}/LiveOS/squashfs-root" "${live_dir}/LiveOS/squashfs.img"
        cmd rm -rf "${live_dir}/LiveOS/squashfs-root"

        task "Making ISO..."
        cmd grub-mkrescue --modules=part_gpt -o "$disk" "$live_dir" -- -volid "$iso_label"

        task "Cleaning up..."
        cmd rm -rf "$live_dir"
        ;;
esac
