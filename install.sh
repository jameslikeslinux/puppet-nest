#!/bin/bash

STAGE_ARCHIVE='https://thestaticvoid.com/dist/stage3-amd64-systemd-20190128.tar.bz2'
DATE="$(date '+%Y%m%d')"

usage() {
    cat >&2 <<END
Usage: install.sh [options] [NAME]

Options:
  -d, --disk DEVICE      the disk to format and install on
                         (can be specified multiple times)
  -e, --encrypt          encrypt the resulting pool
  -n, --dry-run          just print out what would be done
  --partition-only       just partition/format the disks and exit
  -p, --profile PROFILE  the type of system to install
                         (default: 'base')
END
}

ARGS=$(getopt -o "ed:np:" -l "encrypt,disk:,dry-run,partition-only,profile:" -n install.sh -- "$@")

if [ $? -ne 0 ]; then
    usage
    exit 1
fi

eval set -- "$ARGS"

profile='base'

while true; do
    case $1 in
        -d|--disk)
            shift
            disks+=("$1")
            shift
            ;;
        -e|--encrypt)
            shift
            encrypt='yes'
            ;;
        -n|--dry-run)
            shift
            dryrun='yes'
            ;;
        --partition-only)
            shift
            partition_only='yes'
        -p|--profile)
            shift
            profile=$1
            shift
            ;;
        --)
            shift
            break
            ;;
    esac
done

if [ "${#disks[@]}" -eq 0 ]; then
    live='yes'
fi

if [ -d "/sys/firmware/efi/efivars" ]; then
    efi='yes'
fi

if [ -n "$encrypt" -a -n "$live" ]; then
    echo "Live images cannot be encrypted" >&2
    usage
    exit 1
elif [ $# -ne 1 ]; then
    echo "Must specify a name" >&2
    usage
    exit 1
fi

name="$1"


if [ -z "$dryrun" ]; then
    LOGFILE="${PWD}/install-${name}-${DATE}.log"
else
    LOGFILE=/dev/null
fi

echo "Logging to ${LOGFILE}"
echo "Started install at $(date --rfc-3339=seconds)" > "$LOGFILE"


cleanup() {
    task "Cleaning up..."

    # Unmount if necessary
    mountpoint -q "/mnt/${name}" && cmd umount -R "/mnt/${name}"

    # Remove mountpoint if necessary
    if [ -e "/mnt/${name}" ] && [ ! "$(ls -A "/mnt/${name}")" ]; then
        cmd rm -rf "/mnt/${name}"
    fi

    # Disable swap if necessary (assume its on if the device exists)
    [ -e "/dev/zvol/${name}/swap" ] && cmd swapoff "/dev/zvol/${name}/swap"

    # Export pool filesystem if necessary
    zpool list "$name" > /dev/null 2>&1 && cmd zpool export "$name"

    # Close LUKS devices if necessary
    for vdev in "${vdevs[@]}"; do
        [ -e "/dev/mapper/${vdev}" ] && cmd cryptsetup luksClose "$vdev"
    done

    trap - EXIT
}

task() {
    tee -a "$LOGFILE" << END

$@
END
}


cmd() {
    echo "> $@" | tee -a "$LOGFILE"
    if [ -z "$dryrun" ]; then
        "$@" >> "$LOGFILE" 2>&1
        if [ $? -ne 0 ]; then
            echo "FAILED"
            exit 1
        fi
    fi
}


chroot_cmd() {
    echo ">> $@" | tee -a "$LOGFILE"
    if [ -z "$dryrun" ]; then
        FACTER_chroot=true chroot "/mnt/${name}" "$@" >> "$LOGFILE" 2>&1
        if [ $? -ne 0 ]; then
            echo "FAILED"
            exit 1
        fi
    fi
}

if [[ ! $partition_only ]]; then
    echo
    echo -n "Did you make sure ${name} doesn't already have a Puppet certificate? "
    read puppet_clean
    case "$puppet_clean" in
        y*|Y*)
            ;;
        *)
            echo "Check for an existing Puppet cert for ${name} before continuing." >&2
            exit 1
            ;;
    esac
fi


if [ -n "$encrypt" ]; then
    echo -n "Encryption passphrase: "
    read -s enc_passphrase
    echo

    echo -n "Encryption passphrase (again): "
    read -s enc_passphrase_repeat
    echo

    if [ "$enc_passphrase" != "$enc_passphrase_repeat" ]; then
        echo "The passphrases don't match." >&2
        exit 1
    fi
fi


trap cleanup EXIT
task "Making build target..."
cmd mkdir "/mnt/${name}"


if [ -n "$live" ]; then
    live_dir="${PWD}/${name}"

    task "Making live CD directory structure..."
    cmd mkdir -p "${live_dir}/LiveOS/squashfs-root/LiveOS"

    task "Making live CD root image..."
    cmd truncate -s 10G "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img"
    cmd mkfs.ext4 "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img"
    cmd tune2fs -o discard "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img"

    task "Mounting image at build target..."
    cmd mount "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img" "/mnt/${name}"
else
    disk_number=0
    if [ "${#disks[@]}" -gt 1 ]; then
        mirror_number=0
        boot_lvm_flag='on'
        vdevs+=('mirror')
    else
        mirror_number=''
        boot_lvm_flag='off'
    fi

    if [ -n "$efi" ]; then
        partition_flag='esp'
        partition_name_suffix='efi'
    else
        partition_flag='bios_grub'
        partition_name_suffix='bios'
    fi

    if [ -n "$encrypt" ]; then
        partition_name_crypt='-crypt'
    fi

    for disk in "${disks[@]}"; do
        task "Partitioning ${disk}..."
        cmd parted -s "$disk" \
            mklabel gpt \
            mkpart "${name}-${partition_name_suffix}${mirror_number}" 1MiB $((1 + 32))MiB \
            set 1 "$partition_flag" on \
            mkpart "${name}-boot${mirror_number}" $((1 + 32))MiB $((1 + 32 + 512))MiB \
            set 2 lvm "$boot_lvm_flag" \
            mkpart "${name}${partition_name_crypt}${disk_number}" $((1 + 32 + 512))MiB 100% \
            unit s \
            print

        cmd udevadm trigger

        if [ -n "$efi" ]; then
            task "Making EFI system partition ${name}-${partition_name_suffix}${mirror_number}..."
            cmd mkfs.vfat "/dev/disk/by-partlabel/${name}-${partition_name_suffix}${mirror_number}"
        fi

        if [ -n "$encrypt" ]; then
            task "Encrypting ${name}-crypt${disk_number}..."
            echo -n "$enc_passphrase" | cmd cryptsetup luksFormat -c aes-xts-plain64 -s 256 -h sha512 "/dev/disk/by-partlabel/${name}${partition_name_crypt}${disk_number}"
            echo -n "$enc_passphrase" | cmd cryptsetup luksOpen "/dev/disk/by-partlabel/${name}${partition_name_crypt}${disk_number}" "${name}${partition_name_crypt}${disk_number}"
        fi

        vdevs+=("${name}${partition_name_crypt}${disk_number}")

        let disk_number++
        [ "${#disks[@]}" -gt 1 ] && let mirror_number++
    done

    task "Creating ZFS pool..."
    cmd zpool create -f -m none -O compression=lz4 -O xattr=sa -O acltype=posixacl -R "/mnt/${name}" "$name" "${vdevs[@]}"
    cmd zfs create "${name}/ROOT"
    cmd zfs create -o mountpoint=/ "${name}/ROOT/gentoo"
    cmd zfs create -o mountpoint=/var "${name}/ROOT/gentoo/var"
    cmd zfs create -o mountpoint=/home "${name}/home"
    cmd zfs create "${name}/home/james"
    cmd zpool set bootfs="${name}/ROOT/gentoo" "$name"

    task "Creating swap space..."
    cmd zfs create -V 2G -b $(getconf PAGESIZE) -o com.sun:auto-snapshot=false "${name}/swap"
    cmd mkswap "/dev/zvol/${name}/swap"
    cmd swapon --discard "/dev/zvol/${name}/swap"

    task "Creating fscache..."
    cmd zfs create -V 2G -b 4k -o com.sun:auto-snapshot=false "${name}/fscache"
    cmd mkfs.ext4 "/dev/zvol/${name}/fscache"
    cmd tune2fs -o discard "/dev/zvol/${name}/fscache"

    # XXX: This needs to support mdraid
    task "Creating boot filesystem..."
    cmd mkfs.ext2 -L "${name}-boot" "/dev/disk/by-partlabel/${name}-boot"
    cmd mkdir "/mnt/${name}/boot"
    cmd mount LABEL="${name}-boot" "/mnt/${name}/boot"
fi

[[ $partition_only ]] && exit


task "Downloading and extracting stage archive..."
cmd wget --progress=dot:mega "$STAGE_ARCHIVE" -O "/mnt/${name}/$(basename "$STAGE_ARCHIVE")"
cmd tar -C "/mnt/${name}" -xvjpf "/mnt/${name}/$(basename "$STAGE_ARCHIVE")" --xattrs


task "Initializing chroot..."
cmd mount -t proc proc "/mnt/${name}/proc"
cmd mount --rbind /sys "/mnt/${name}/sys"
cmd mount --make-rslave "/mnt/${name}/sys"
cmd mount --rbind /dev "/mnt/${name}/dev"
cmd mount --make-rslave "/mnt/${name}/dev"
cmd mkdir "/mnt/${name}/nest"
cmd mount --rbind /nest "/mnt/${name}/nest"
cmd mount --make-rslave "/mnt/${name}/nest"
cmd cp -L /etc/resolv.conf "/mnt/${name}/etc/resolv.conf"


task "Prepping build target..."
cmd tee "/mnt/${name}/etc/portage/make.conf" <<END
CFLAGS="-march=haswell -O2 -pipe -ggdb"
CXXFLAGS="-march=haswell -O2 -pipe -ggdb"
CPU_FLAGS_X86="aes avx avx2 fma3 mmx mmxext popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
DISTDIR="/nest/portage/distfiles"
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --usepkg"
FEATURES="buildpkg splitdebug"
PKGDIR="/nest/portage/packages/amd64-base"
END
cmd tee "/mnt/${name}/etc/portage/repos.conf" <<END
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/cache/portage/gentoo
END
cmd rm -rf "/mnt/${name}/etc/portage/make.conf.catalyst"
cmd rm -rf "/mnt/${name}/etc/portage/package."*


task "Installing Portage tree..."
cmd wget --progress=dot:mega https://github.com/iamjamestl/portage-gentoo/archive/master.tar.gz -O "/mnt/${name}/portage-gentoo-master.tar.gz"
cmd mkdir -p "/mnt/${name}/var/cache/portage/gentoo"
cmd tar -C "/mnt/${name}/var/cache/portage/gentoo" --strip 1 -xvzf "/mnt/${name}/portage-gentoo-master.tar.gz"
cmd rm -f "/mnt/${name}/portage-gentoo-master.tar.gz"
chroot_cmd eselect profile set default/linux/amd64/17.0/systemd


task "Installing Puppet..."
chroot_cmd emerge -v '<app-admin/puppet-agent-6' app-portage/eix


task "Prepping for Puppet run..."
chroot_cmd mkdir -p /etc/puppetlabs/facter/facts.d
chroot_cmd tee /etc/puppetlabs/facter/facts.d/nest.yaml <<END
---
nest:
  profile: '${profile}'
END
[ -n "$live" ] && chroot_cmd tee -a /etc/puppetlabs/facter/facts.d/nest.yaml <<END
  live: true
END


task "Running Puppet..."
chroot_cmd puppet agent --onetime --verbose --no-daemonize --no-splay --show_diff --certname "$name" --server puppet.nest
[ -z "$live" ] && chroot_cmd systemctl enable puppet

task "Removing unnecessary packages..."
chroot_cmd emerge --depclean


if [ -n "$live" ]; then
    iso_label=$(echo "$name" | tr 'a-z' 'A-Z')

    task "Configuring live CD boot..."
    cmd mkdir "${live_dir}/boot"
    cmd mv "/mnt/${name}/boot/"* "${live_dir}/boot/"
    cmd sed -i -r '/insmod ext2/,/fi/d; s/root=UUID=[[:graph:]]+/root=live:LABEL='"$iso_label"'/g' "${live_dir}/boot/grub/grub.cfg"

    cleanup

    task "Making squashfs.img..."
    cmd mksquashfs "${live_dir}/LiveOS/squashfs-root" "${live_dir}/LiveOS/squashfs.img" -comp xz
    cmd rm -rf "${live_dir}/LiveOS/squashfs-root"

    task "Making ISO..."
    cmd grub-mkrescue --modules=part_gpt -o "${name}-${DATE}.iso" "$live_dir" -- -volid "$iso_label"
fi
