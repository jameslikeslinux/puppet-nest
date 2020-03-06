#!/bin/bash

STAGE_ARCHIVE_AMD64='https://thestaticvoid.com/dist/stage3-amd64-systemd-20190523.tar.bz2'
STAGE_ARCHIVE_ARMV7A='https://bouncer.gentoo.org/fetch/root/all/releases/arm/autobuilds/20180831/stage3-armv7a_hardfp-20180831.tar.bz2'
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

ARGS=$(getopt -o "ed:np:" -l "encrypt,disk:,dry-run,partition-only,profile:,resume" -n install.sh -- "$@")

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
            ;;
        -p|--profile)
            shift
            profile=$1
            shift
            ;;
        --resume)
            shift
            resume='yes'
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

if [[ -d "/sys/firmware/efi/efivars" ]]; then
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

destructive_cmd() {
    [[ $resume ]] || cmd "$@"
}

chroot_cmd() {
    echo ">> $@" | tee -a "$LOGFILE"
    if [ -z "$dryrun" ]; then
        systemd-nspawn --console=pipe -q -E FACTER_chroot=true --bind=/dev --bind=/nest --capability=all --property='DeviceAllow=block-* rwm' -D "/mnt/${name}" "$@" >> "$LOGFILE" 2>&1
        if [ $? -ne 0 ]; then
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
    [[ -d "/mnt/${name}${1}" ]] || chroot_cmd mkdir -p "$1"
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
make_dir "/mnt/${name}"


if [ -n "$live" ]; then
    live_dir="${PWD}/${name}"

    task "Making live CD directory structure..."
    make_dir "${live_dir}/LiveOS/squashfs-root/LiveOS"

    task "Making live CD root image..."
    destructive_cmd truncate -s 10G "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img"
    destructive_cmd mkfs.ext4 "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img"
    destructive_cmd tune2fs -o discard "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img"

    task "Mounting image at build target..."
    cmd mount "${live_dir}/LiveOS/squashfs-root/LiveOS/rootfs.img" "/mnt/${name}"
else
    if [ "${#disks[@]}" -gt 1 ]; then
        mirror_number=1
        boot_lvm_flag='on'
        vdevs+=('mirror')
    else
        mirror_number=''
        boot_lvm_flag='off'
    fi

    if [ -n "$efi" ]; then
        partition_name_suffix='efi'
        firmware_partition_type='C12A7328-F81F-11D2-BA4B-00A0C93EC93B'
    else
        partition_name_suffix='bios'
        firmware_partition_type='21686148-6449-6E6F-744E-656564454649'
    fi

    if [ -n "$encrypt" ]; then
        partition_name_crypt='-crypt'
    fi

    for disk in "${disks[@]}"; do
        task "Partitioning ${disk}..."

        destructive_cmd sfdisk "$disk" <<END
label: gpt
size=32MiB, type=${firmware_partition_type}, name="${name}-${partition_name_suffix}${mirror_number}"
size=512MiB, type=BC13C2FF-59E6-4262-A352-B275FD6F7172, name="${name}-boot${mirror_number}"
name="${name}"
END

        vdevs+=("${name}${partition_name_crypt}${mirror_number}")

        destructive_cmd udevadm trigger
        destructive_cmd sleep 3

        if [ -n "$efi" ]; then
            task "Making EFI system partition ${name}-${partition_name_suffix}${mirror_number}..."
            destructive_cmd mkfs.vfat "/dev/disk/by-partlabel/${name}-${partition_name_suffix}${mirror_number}"
        fi

        if [ -n "$encrypt" ]; then
            task "Encrypting ${name}-crypt${mirror_number}..."
            echo -n "$enc_passphrase" | destructive_cmd cryptsetup luksFormat -c aes-xts-plain64 -s 256 -h sha512 "/dev/disk/by-partlabel/${name}${partition_name_crypt}${mirror_number}"
            echo -n "$enc_passphrase" | destructive_cmd cryptsetup luksOpen "/dev/disk/by-partlabel/${name}${partition_name_crypt}${mirror_number}" "${name}${partition_name_crypt}${mirror_number}"
        fi

        [ "${#disks[@]}" -gt 1 ] && let mirror_number++
    done

    if [[ $resume ]]; then
        task "Importing ZFS pool..."
        cmd zpool import -R "/mnt/${name}" "$name"
    else
        task "Creating ZFS pool..."
        destructive_cmd zpool create -f -m none -O compression=lz4 -O xattr=sa -O acltype=posixacl -R "/mnt/${name}" "$name" "${vdevs[@]}"
        destructive_cmd zfs create "${name}/ROOT"
        destructive_cmd zfs create -o mountpoint=/ "${name}/ROOT/gentoo"
        destructive_cmd zfs create -o mountpoint=/var "${name}/ROOT/gentoo/var"
        destructive_cmd zfs create -o mountpoint=/home "${name}/home"
        destructive_cmd zfs create "${name}/home/james"
        destructive_cmd zpool set bootfs="${name}/ROOT/gentoo" "$name"
    fi

    task "Creating swap space..."
    destructive_cmd zfs create -V 2G -b $(getconf PAGESIZE) -o com.sun:auto-snapshot=false "${name}/swap"
    destructive_cmd udevadm trigger
    destructive_cmd sleep 3
    destructive_cmd mkswap -L "${name}-swap" "/dev/zvol/${name}/swap"
    # cmd swapon --discard "/dev/zvol/${name}/swap"

    if [[ $profile != 'beaglebone' ]]; then
        task "Creating fscache..."
        destructive_cmd zfs create -V 2G -o com.sun:auto-snapshot=false "${name}/fscache"
        destructive_cmd mkfs.ext4 -L "${name}-fscache" "/dev/zvol/${name}/fscache"
        destructive_cmd tune2fs -o discard "/dev/zvol/${name}/fscache"
    fi

    # XXX: This needs to support mdraid
    task "Creating boot filesystem..."
    destructive_cmd mkfs.vfat "/dev/disk/by-partlabel/${name}-boot"
    make_dir "/mnt/${name}/boot"
    cmd mount PARTLABEL="${name}-boot" "/mnt/${name}/boot"

    if [ -n "$efi" ]; then
        make_dir "/mnt/${name}/efi"
        cmd mount PARTLABEL="${name}-efi" "/mnt/${name}/efi"
    fi
fi

[[ $partition_only ]] && exit


case "$profile" in
    'beaglebone')
        STAGE_ARCHIVE="$STAGE_ARCHIVE_ARMV7A"
        ;;
    *)
        STAGE_ARCHIVE="$STAGE_ARCHIVE_AMD64"
        ;;
esac

task "Downloading and extracting stage archive..."
destructive_cmd wget --progress=dot:mega "$STAGE_ARCHIVE" -O "/mnt/${name}/$(basename "$STAGE_ARCHIVE")"
destructive_cmd tar -C "/mnt/${name}" -xvjpf "/mnt/${name}/$(basename "$STAGE_ARCHIVE")" --xattrs


task "Prepping build target..."

if [[ $profile == 'beaglebone' ]]; then
    destructive_cmd cp /usr/bin/qemu-arm "/mnt/${name}/usr/bin/qemu-arm"
    makeopts="$(grep '^MAKEOPTS=' /etc/portage/make.conf)"
    destructive_cmd tee "/mnt/${name}/etc/portage/make.conf" <<END
CFLAGS="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -O2 -pipe -ggdb"
CXXFLAGS="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -O2 -pipe -ggdb"
DISTDIR="/nest/portage/distfiles"
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --usepkg"
FEATURES="buildpkg splitdebug -sandbox -usersandbox -pid-sandbox -network-sandbox"
PKGDIR="/nest/portage/packages/armv7l-beaglebone"
USE="X"
$makeopts
END
else
    destructive_cmd tee "/mnt/${name}/etc/portage/make.conf" <<END
CFLAGS="-march=haswell -O2 -pipe -ggdb"
CXXFLAGS="-march=haswell -O2 -pipe -ggdb"
CPU_FLAGS_X86="aes avx avx2 fma3 mmx mmxext popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
DISTDIR="/nest/portage/distfiles"
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --usepkg"
FEATURES="buildpkg splitdebug"
PKGDIR="/nest/portage/packages/amd64-base"
END
fi
destructive_cmd tee "/mnt/${name}/etc/portage/repos.conf" <<END
[DEFAULT]
main-repo = gentoo

[gentoo]
location = /var/cache/portage/gentoo
END
destructive_cmd rm -rf "/mnt/${name}/etc/portage/make.conf.catalyst"
destructive_cmd rm -rf "/mnt/${name}/etc/portage/package."*


task "Installing Portage tree..."
destructive_cmd wget --progress=dot:mega https://github.com/iamjamestl/portage-gentoo/archive/master.tar.gz -O "/mnt/${name}/portage-gentoo-master.tar.gz"
make_dir "/mnt/${name}/var/cache/portage/gentoo"
destructive_cmd tar -C "/mnt/${name}/var/cache/portage/gentoo" --strip 1 -xvzf "/mnt/${name}/portage-gentoo-master.tar.gz"
destructive_cmd rm -f "/mnt/${name}/portage-gentoo-master.tar.gz"


if [[ $profile == 'beaglebone' ]]; then
    destructive_chroot_cmd eselect profile set default/linux/arm/17.0/armv7a/systemd
    destructive_chroot_cmd emerge -vDuN --with-bdeps=y @world
    destructive_chroot_cmd emerge --depclean
else
    destructive_chroot_cmd eselect profile set default/linux/amd64/17.0/systemd
fi

extra_puppet_args=()

task "Installing Puppet..."
if [[ $profile == 'beaglebone' ]]; then
    extra_puppet_args+=('--logdir' '/var/log/puppet' '--rundir' '/var/run/puppet' '--vardir' '/var/lib/puppet')

    chroot_make_dir /etc/portage/package.keywords
    destructive_chroot_cmd tee /etc/portage/package.keywords/puppet <<END
app-admin/puppet
dev-ruby/hiera
dev-ruby/deep_merge
dev-ruby/hocon
dev-ruby/facter
dev-cpp/cpp-hocon
dev-cpp/yaml-cpp
dev-libs/leatherman
dev-ruby/ruby-augeas
app-admin/augeas
app-doc/NaturalDocs
END
    destructive_chroot_cmd emerge -v '<app-admin/puppet-6' app-portage/eix dev-ruby/ruby-augeas
else
    destructive_chroot_cmd env USE=tinfo emerge -v '<app-admin/puppet-agent-6' app-portage/eix
fi

# Allow the systemd service provider to work inside the chroot
destructive_cmd sed -i 's/confine/#confine/' /mnt/"$name"/usr/lib/ruby/gems/*/gems/puppet-*/lib/puppet/provider/service/systemd.rb


task "Prepping for Puppet run..."
chroot_make_dir /etc/puppetlabs/facter/facts.d
destructive_chroot_cmd tee /etc/puppetlabs/facter/facts.d/nest.yaml <<END
---
nest:
  profile: '${profile}'
END
[ -n "$live" ] && destructive_chroot_cmd tee -a /etc/puppetlabs/facter/facts.d/nest.yaml <<END
  live: true
END


task "Running Puppet..."
chroot_cmd puppet agent --onetime --debug --no-daemonize --no-splay --show_diff --certname "$name" --server puppet.nest "${extra_puppet_args[@]}"
[ -z "$live" ] && chroot_cmd systemctl enable puppet

# task "Removing unnecessary packages..."
# chroot_cmd emerge --depclean


if [ -n "$live" ]; then
    iso_label=$(echo "$name" | tr 'a-z' 'A-Z')

    task "Configuring live CD boot..."
    make_dir "${live_dir}/boot"
    cmd mv "/mnt/${name}/boot/"* "${live_dir}/boot/"
    cmd sed -i -r '/insmod ext2/,/fi/d; s/root=UUID=[[:graph:]]+/root=live:LABEL='"$iso_label"'/g' "${live_dir}/boot/grub/grub.cfg"

    cleanup

    task "Making squashfs.img..."
    cmd mksquashfs "${live_dir}/LiveOS/squashfs-root" "${live_dir}/LiveOS/squashfs.img" -comp xz
    cmd rm -rf "${live_dir}/LiveOS/squashfs-root"

    task "Making ISO..."
    cmd grub-mkrescue --modules=part_gpt -o "${name}-${DATE}.iso" "$live_dir" -- -volid "$iso_label"
fi
