#!/bin/bash

STAGE_ARCHIVE=https://thestaticvoid.com/dist/stage3-amd64-20160519.tar.bz2
DATE=$(date '+%Y%m%d')

usage() {
    cat >&2 <<END
Usage: install.sh [options] [NAME]

Options:
  -d, --disk DEVICE      the disk to format and install on
                         (can be specified multiple times)
  -e, --encrypt          encrypt the resulting pool
  -n, --dry-run          just print out what would be done
  -p, --profile PROFILE  the type of system to install
                         (default: 'base')
END
}

ARGS=$(getopt -o "ed:np:" -l "encrypt,disk:,dry-run,profile:" -n install.sh -- "$@")

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
    mountpoint -q "/mnt/${name}" && command umount -R "/mnt/${name}"

    # Disable swap if necessary (assume its on if the device exists)
    [ -e "/dev/zvol/${name}/swap" ] && command swapoff "/dev/zvol/${name}/swap"

    # Export pool if necessary
    zpool list "$name" > /dev/null 2>&1 && command zpool export "$name"

    # Close LUKS devices if necessary
    for vdev in "${vdevs[@]}"; do
        [ -e "/dev/mapper/${vdev}" ] && command cryptsetup luksClose "$vdev"
    done

    # Remove mountpoint if necessary
    if [ -e "/mnt/${name}" ] && [ ! "$(ls -A "/mnt/${name}")" ]; then
        command rm -rf "/mnt/${name}"
    fi

    trap - EXIT
}

task() {
    tee -a "$LOGFILE" << END

$@
END
}


command() {
    echo "> $@" | tee -a "$LOGFILE"
    if [ -z "$dryrun" ]; then
        "$@" >> "$LOGFILE" 2>&1
        if [ $? -ne 0 ]; then
            echo "FAILED"
            exit 1
        fi
    fi
}


chroot_command() {
    echo ">> $@" | tee -a "$LOGFILE"
    if [ -z "$dryrun" ]; then
        FACTER_chroot=true chroot "/mnt/${name}" "$@" >> "$LOGFILE" 2>&1
        if [ $? -ne 0 ]; then
            echo "FAILED"
            exit 1
        fi
    fi
}

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
command mkdir "/mnt/${name}"


if [ -n "$live" ]; then
    live_dir="${PWD}/${name}"

    task "Making live CD directory structure..."
    command mkdir -p "${live_dir}/LiveOS/squashfs-root/LiveOS"

    task "Making live CD root image..."
    command truncate -s 10G "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img"
    command mkfs.ext4 "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img"
    command tune2fs -o discard "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img"

    task "Mounting image at build target..."
    command mount "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img" "/mnt/${name}"
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
        command parted -s "$disk" \
            mklabel gpt \
            mkpart "${name}-${partition_name_suffix}${mirror_number}" 1MiB $((1 + 32))MiB \
            set 1 "$partition_flag" on \
            mkpart "${name}-boot${mirror_number}" $((1 + 32))MiB $((1 + 32 + 512))MiB \
            set 2 lvm "$boot_lvm_flag" \
            mkpart "${name}${partition_name_crypt}${disk_number}" $((1 + 32 + 512))MiB 100% \
            unit s \
            print

        command udevadm trigger

        if [ -n "$efi" ]; then
            task "Making EFI system partition ${name}-${partition_name_suffix}${mirror_number}..."
            command mkfs.vfat "${name}-${partition_name_suffix}${mirror_number}"
        fi

        if [ -n "$encrypt" ]; then
            task "Encrypting ${name}-crypt${disk_number}..."
            echo -n "$enc_passphrase" | command cryptsetup luksFormat -c aes-xts-plain64 -s 256 -h sha512 "/dev/disk/by-partlabel/${name}${partition_name_crypt}${disk_number}"
            echo -n "$enc_passphrase" | command cryptsetup luksOpen "/dev/disk/by-partlabel/${name}${partition_name_crypt}${disk_number}" "${name}${partition_name_crypt}${disk_number}"
        fi

        vdevs+=("${name}${partition_name_crypt}${disk_number}")

        let disk_number++
        [ "${#disks[@]}" -gt 1 ] && let mirror_number++
    done

    task "Creating ZFS pool..."
    command zpool create -f -m none -O compression=lz4 -O xattr=sa -O acltype=posixacl -R "/mnt/${name}" "$name" "${vdevs[@]}"
    command zfs create "${name}/ROOT"
    command zfs create -o mountpoint=/ "${name}/ROOT/gentoo"
    command zfs create -o mountpoint=/usr/portage "${name}/ROOT/gentoo/portage"
    command zfs create -o mountpoint=/var "${name}/ROOT/gentoo/var"
    command zfs create -o mountpoint=/home "${name}/home"
    command zfs create "${name}/home/james"
    command zpool set bootfs="${name}/ROOT/gentoo" "$name"

    task "Creating swap space..."
    command zfs create -V 2G -b $(getconf PAGESIZE) -o com.sun:auto-snapshot=false "${name}/swap"
    command mkswap "/dev/zvol/${name}/swap"
    command swapon --discard "/dev/zvol/${name}/swap"

    # XXX: This needs to support mdraid
    task "Creating boot filesystem..."
    command mkfs.ext2 -L "${name}-boot" "/dev/disk/by-partlabel/${name}-boot"
    command mkdir "/mnt/${name}/boot"
    command mount LABEL="${name}-boot" "/mnt/${name}/boot"
fi


task "Downloading and extracting stage archive..."
command wget --progress=dot:mega "$STAGE_ARCHIVE" -O "/mnt/${name}/$(basename "$STAGE_ARCHIVE")"
command tar -C "/mnt/${name}" -xvjpf "/mnt/${name}/$(basename "$STAGE_ARCHIVE")" --xattrs


task "Initializing chroot..."
command mount -t proc proc "/mnt/${name}/proc"
command mount --rbind /sys "/mnt/${name}/sys"
command mount --make-rslave "/mnt/${name}/sys"
command mount --rbind /dev "/mnt/${name}/dev"
command mount --make-rslave "/mnt/${name}/dev"
command mkdir "/mnt/${name}/nest"
command mount --rbind /nest "/mnt/${name}/nest"
command mount --make-rslave "/mnt/${name}/nest"
command cp -L /etc/resolv.conf "/mnt/${name}/etc/resolv.conf"


task "Prepping build target..."
command tee "/mnt/${name}/etc/portage/make.conf" <<END
CFLAGS="-march=core-avx-i -O2 -pipe -ggdb"
CXXFLAGS="-march=core-avx-i -O2 -pipe -ggdb"
CPU_FLAGS_X86="aes avx mmx mmxext popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --usepkg"
FEATURES="buildpkg splitdebug"
PKGDIR="/nest/packages/amd64-base"
END
command rm -rf "/mnt/${name}/etc/portage/package."*


task "Installing Portage tree..."
command wget --progress=dot:mega https://github.com/iamjamestl/portage-gentoo/archive/master.tar.gz -O "/mnt/${name}/portage-gentoo-master.tar.gz"
[ ! -d "/mnt/${name}/usr/portage" ] && command mkdir "/mnt/${name}/usr/portage"
command tar -C "/mnt/${name}/usr/portage" --strip 1 -xvzf "/mnt/${name}/portage-gentoo-master.tar.gz"
command rm -f "/mnt/${name}/portage-gentoo-master.tar.gz"


task "Installing Puppet..."
chroot_command emerge -v app-admin/puppet-agent app-portage/eix dev-vcs/git


task "Prepping for Puppet run..."
# Facter and ZFS need a valid mtab
# (normally systemd creates this on boot)
chroot_command ln -s ../proc/self/mounts /etc/mtab
chroot_command mkdir -p /etc/puppetlabs/facter/facts.d
chroot_command tee /etc/puppetlabs/facter/facts.d/nest.yaml <<END
---
nest:
  profile: 'base'
  live: true
END


task "Running Puppet..."
chroot_command puppet agent --onetime --verbose --no-daemonize --no-splay --show_diff --certname "$name" --server hawk.nest --environment development


if [ -n "$live" ]; then
    iso_label=$(echo "$name" | tr 'a-z' 'A-Z')

    task "Minimizing the image..."
    command rm -rf "/mnt/${name}/$(basename "$STAGE_ARCHIVE")" "/mnt/${name}/usr/lib/debug" "/mnt/${name}/usr/portage" "/mnt/${name}/usr/src/"*

    task "Configuring live CD boot..."
    command mkdir "${live_dir}/boot"
    command mv "/mnt/${name}/boot/"* "${live_dir}/boot/"
    command chmod +r "${live_dir}/boot/initramfs"*
    command sed -i -r '/insmod ext2/,/fi/d; s/root=UUID=[[:graph:]]+/root=live:LABEL='"$iso_label"'_FULL/g' "${live_dir}/boot/grub/grub.cfg"

    cleanup

    task "Making squashfs.img..."
    command mksquashfs "${live_dir}/LiveOS/squashfs-root" "${live_dir}/LiveOS/squashfs.img" -comp xz
    command rm -rf "${live_dir}/LiveOS/squashfs-root"

    task "Making full ISO..."
    command grub2-mkrescue --modules=part_gpt -o "${live_dir}/${name}-full-${DATE}.iso" "$live_dir" -- -volid "${iso_label}_FULL"

    task "Making netboot ISO..."
    command mkdir -p "${live_dir}/net"
    command cp -a "${live_dir}/boot" "${live_dir}/net/"
    command sed -i -r 's@root=[[:graph:]]+@root=live:https://thestaticvoid.com/'"$name"'/LiveOS/squashfs.img@g' "${live_dir}/net/boot/grub/grub.cfg"
    command grub2-mkrescue --modules=part_gpt -o "${live_dir}/${name}-net-${DATE}.iso" "${live_dir}/net" -- -volid "${iso_label}_NET"
    command rm -rf "${live_dir}/net"
fi
