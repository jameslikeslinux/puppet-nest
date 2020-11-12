#!/bin/bash

STAGE_ARCHIVE_AMD64='https://thestaticvoid.com/dist/stage3-amd64-systemd-20190523.tar.bz2'
STAGE_ARCHIVE_ARMV7A='https://bouncer.gentoo.org/fetch/root/all/releases/arm/autobuilds/20180831/stage3-armv7a_hardfp-20180831.tar.bz2'
STAGE_ARCHIVE_ARM64='https://thestaticvoid.com/dist/stage3-arm64-systemd-20201004T190540Z.tar.xz'
DATE="$(date '+%Y%m%d')"

usage() {
    cat >&2 <<END
Usage: install.sh [options] [NAME]

Options:
  -d, --disk DEVICE        the disk to format and install on
  -e, --encrypt            encrypt the resulting pool
  -n, --dry-run            just print out what would be done
  --partition-only         just partition/format the disk and exit
  -p, --platform PLATFORM  the type of system on which to install
                           (default: 'generic')
  -r, --role ROLE          the type of system to install
                           (default: 'server')
  --resume                 mount and resume install at puppet stage
  --shell                  mount and launch a shell inside the chroot
END
}

ARGS=$(getopt -o "ed:np:r:" -l "encrypt,disk:,dry-run,partition-only,platform:,role:,resume,shell" -n install.sh -- "$@")

if [ $? -ne 0 ]; then
    usage
    exit 1
fi

eval set -- "$ARGS"

platform='generic'
role='server'

while true; do
    case $1 in
        -d|--disk)
            shift
            disk="$1"
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
        -p|--platform)
            shift
            platform=$1
            shift
            ;;
        -r|--role)
            shift
            role=$1
            shift
            ;;
        --resume)
            shift
            resume='yes'
            ;;
        --shell)
            shift
            resume='yes'
            shell='yes'
            ;;
        --)
            shift
            break
            ;;
    esac
done

if [[ $disk == '' ]]; then
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
    mountpoint -q "/mnt/${name}" && fallable_cmd umount -R "/mnt/${name}"

    # Remove mountpoint if necessary
    if [ -e "/mnt/${name}" ] && [ ! "$(ls -A "/mnt/${name}")" ]; then
        fallable_cmd rm -rf "/mnt/${name}"
    fi

    # Disable swap if necessary (assume its on if the device exists)
    [ -e "/dev/zvol/${zroot}/swap" ] && fallable_cmd swapoff "/dev/zvol/${zroot}/swap" && sleep 1

    # Export pool filesystem if necessary
    zpool list "$name" > /dev/null 2>&1 && fallable_cmd zpool export "$name"

    trap - EXIT
}

task() {
    tee -a "$LOGFILE" << END

$@
END
}

fallable_cmd() {
    echo "> $@" | tee -a "$LOGFILE"
    if [ -z "$dryrun" ]; then
        "$@" >> "$LOGFILE" 2>&1
    fi
}

cmd() {
    fallable_cmd "$@"
    if [ $? -ne 0 ]; then
        echo "FAILED"
        exit 1
    fi
}

destructive_cmd() {
    [[ $resume ]] || cmd "$@"
}

chroot_cmd() {
    echo ">> $@" | tee -a "$LOGFILE"
    if [ -z "$dryrun" ]; then
        systemd-nspawn --console=pipe -q -E FACTER_chroot=true -E LANG=en_US.UTF-8 --bind=/dev --bind=/nest --capability=all --property='DeviceAllow=block-* rwm' -D "/mnt/${name}" "$@" >> "$LOGFILE" 2>&1
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

if [[ ! $partition_only && ! $resume ]]; then
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


zroot=$name

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
    task "Partitioning ${disk}..."

    if [ -n "$efi" ]; then
        destructive_cmd sfdisk "$disk" <<END
label: gpt
start=32768, size=512MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="${name}-boot"
name="${name}"
END
    else
        destructive_cmd sfdisk "$disk" <<END
label: gpt
size=32MiB, type=21686148-6449-6E6F-744E-656564454649, name="${name}-bios"
size=512MiB, type=BC13C2FF-59E6-4262-A352-B275FD6F7172, name="${name}-boot"
name="${name}"
END
    fi

    destructive_cmd udevadm trigger
    destructive_cmd sleep 3

    if [ -n "$efi" ]; then
        task "Making EFI system partition ${name}-boot..."
        destructive_cmd mkfs.vfat "/dev/disk/by-partlabel/${name}-boot"
    fi

    if [[ $resume ]]; then
        task "Importing ZFS pool..."
        cmd zpool import -l -R "/mnt/${name}" "$name" <<< "$enc_passphrase"
    else
        task "Creating ZFS pool..."
        destructive_cmd zpool create -f -m none -o ashift=9 -O compression=lz4 -O xattr=sa -O acltype=posixacl -R "/mnt/${name}" "$name" "$name"
        [[ $encrypt ]] && destructive_cmd zfs create -o encryption=aes-128-gcm -o keyformat=passphrase -o keylocation=prompt "$zroot" <<< "$enc_passphrase"
        destructive_cmd zfs create "${zroot}/ROOT"
        destructive_cmd zfs create -o mountpoint=/ "${zroot}/ROOT/gentoo"
        destructive_cmd zfs create -o mountpoint=/var "${zroot}/ROOT/gentoo/var"
        destructive_cmd zfs create -o mountpoint=/home "${zroot}/home"
        destructive_cmd zfs create "${zroot}/home/james"
        destructive_cmd zpool set bootfs="${zroot}/ROOT/gentoo" "$name"
    fi

    task "Creating swap space..."
    destructive_cmd zfs create -V 4G -b $(getconf PAGESIZE) "${zroot}/swap"
    destructive_cmd udevadm trigger
    destructive_cmd sleep 3
    destructive_cmd mkswap -L "${name}-swap" "/dev/zvol/${zroot}/swap"
    cmd swapon --discard "/dev/zvol/${zroot}/swap"

    if [[ $platform != 'beagleboneblack' ]]; then
        task "Creating fscache..."
        destructive_cmd zfs create -V 2G "${zroot}/fscache"
        destructive_cmd udevadm trigger
        destructive_cmd sleep 3
        destructive_cmd mkfs.ext4 -L "${name}-fscache" "/dev/zvol/${zroot}/fscache"
        destructive_cmd tune2fs -o discard "/dev/zvol/${zroot}/fscache"
    fi

    # XXX: This needs to support mdraid
    task "Creating boot filesystem..."
    destructive_cmd mkfs.vfat "/dev/disk/by-partlabel/${name}-boot"
    make_dir "/mnt/${name}/boot"
    cmd mount PARTLABEL="${name}-boot" "/mnt/${name}/boot"
fi

[[ $partition_only ]] && exit

if [[ $shell ]]; then
    task "Launching shell..."
    systemd-nspawn --console=pipe -q -E FACTER_chroot=true -E LANG=en_US.UTF-8 --bind=/dev --bind=/nest --capability=all --property='DeviceAllow=block-* rwm' -D "/mnt/${name}" bash
    exit
fi


case "$platform" in
    'beagleboneblack')
        STAGE_ARCHIVE="$STAGE_ARCHIVE_ARMV7A"
        ;;
    'pinebookpro'|'raspberrypi')
        STAGE_ARCHIVE="$STAGE_ARCHIVE_ARM64"
        ;;
    *)
        STAGE_ARCHIVE="$STAGE_ARCHIVE_AMD64"
        ;;
esac

task "Downloading and extracting stage archive..."
destructive_cmd wget --progress=dot:mega "$STAGE_ARCHIVE" -O "/mnt/${name}/$(basename "$STAGE_ARCHIVE")"
destructive_cmd tar -C "/mnt/${name}" -xvpf "/mnt/${name}/$(basename "$STAGE_ARCHIVE")" --xattrs


task "Prepping build target..."

case "$platform" in
    'beagleboneblack')
        destructive_cmd cp /usr/bin/qemu-arm "/mnt/${name}/usr/bin/qemu-arm"
        destructive_cmd tee "/mnt/${name}/etc/portage/make.conf" <<END
CFLAGS="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -O2 -pipe -ggdb"
CXXFLAGS="-march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=hard -O2 -pipe -ggdb"
DISTDIR="/nest/portage/distfiles"
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --usepkg"
FEATURES="buildpkg splitdebug -sandbox -usersandbox -pid-sandbox -network-sandbox"
MAKEOPTS="-j$(nproc)"
PKGDIR="/nest/portage/packages/armv7l-server.cortex-a8"
USE="X"
END
        ;;

    'pinebookpro')
        destructive_cmd cp /usr/bin/qemu-aarch64 "/mnt/${name}/usr/bin/qemu-aarch64"
        destructive_cmd tee "/mnt/${name}/etc/portage/make.conf" <<END
CFLAGS="-mcpu=cortex-a72.cortex-a53+crypto -O2 -pipe -ggdb"
CXXFLAGS="-mcpu=cortex-a72.cortex-a53+crypto -O2 -pipe -ggdb"
DISTDIR="/nest/portage/distfiles"
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --usepkg"
FEATURES="buildpkg splitdebug -sandbox -usersandbox -pid-sandbox -network-sandbox"
MAKEOPTS="-j$(nproc)"
PKGDIR="/nest/portage/packages/aarch64-server.cortex-a72.cortex-a53+crypto"
USE="X"
END
        ;;

    'raspberrypi')
        destructive_cmd cp /usr/bin/qemu-aarch64 "/mnt/${name}/usr/bin/qemu-aarch64"
        destructive_cmd tee "/mnt/${name}/etc/portage/make.conf" <<END
CFLAGS="-mcpu=cortex-a72 -O2 -pipe -ggdb"
CXXFLAGS="-mcpu=cortex-a72 -O2 -pipe -ggdb"
DISTDIR="/nest/portage/distfiles"
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --usepkg"
FEATURES="buildpkg splitdebug -sandbox -usersandbox -pid-sandbox -network-sandbox"
MAKEOPTS="-j$(nproc)"
PKGDIR="/nest/portage/packages/aarch64-server.cortex-a72"
USE="X"
END
        ;;

    *)
        destructive_cmd tee "/mnt/${name}/etc/portage/make.conf" <<END
CFLAGS="-march=haswell -O2 -pipe -ggdb"
CXXFLAGS="-march=haswell -O2 -pipe -ggdb"
CPU_FLAGS_X86="aes avx avx2 fma3 mmx mmxext popcnt sse sse2 sse3 sse4_1 sse4_2 ssse3"
DISTDIR="/nest/portage/distfiles"
EMERGE_DEFAULT_OPTS="\${EMERGE_DEFAULT_OPTS} --usepkg"
FEATURES="buildpkg splitdebug"
MAKEOPTS="-j$(nproc)"
PKGDIR="/nest/portage/packages/amd64-server.haswell"
END
esac

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


case "$platform" in
    'beagleboneblack')
        destructive_chroot_cmd eselect profile set default/linux/arm/17.0/armv7a/systemd
        ;;

    'pinebookpro'|'raspberrypi')
        destructive_chroot_cmd eselect profile set default/linux/arm64/17.0/systemd
        ;;

    *)
        destructive_chroot_cmd eselect profile set default/linux/amd64/17.1/systemd
        ;;
esac

task "Updating Stage 3..."
destructive_chroot_cmd emerge --oneshot portage
destructive_chroot_cmd emerge -vDuN --with-bdeps=y @world
destructive_chroot_cmd emerge --depclean

task "Installing Puppet..."
chroot_make_dir /etc/portage/package.accept_keywords
destructive_chroot_cmd tee /etc/portage/package.accept_keywords/default <<END
app-admin/augeas ~*
app-admin/puppet ~*
app-doc/NaturalDocs ~*
app-emulation/virt-what ~*
dev-cpp/cpp-hocon ~*
dev-cpp/yaml-cpp ~*
dev-libs/leatherman ~*
dev-ruby/concurrent-ruby ~*
dev-ruby/deep_merge ~*
dev-ruby/facter ~*
dev-ruby/hiera ~*
dev-ruby/hocon ~*
dev-ruby/ruby-augeas ~*
dev-ruby/ruby-shadow ~*
dev-ruby/semantic_puppet ~*
END
chroot_make_dir /etc/portage/package.use
destructive_chroot_cmd tee /etc/portage/package.use/default <<END
app-admin/puppet augeas shadow
END
destructive_chroot_cmd emerge -v app-admin/puppet app-portage/eix

# Allow the systemd service provider to work inside the chroot
destructive_cmd sed -i 's/confine/#confine/' /mnt/"$name"/usr/lib*/ruby/gems/*/gems/puppet-*/lib/puppet/provider/service/systemd.rb


task "Prepping for Puppet run..."
chroot_make_dir /etc/puppetlabs/facter/facts.d
destructive_chroot_cmd tee /etc/puppetlabs/facter/facts.d/nest.yaml <<END
---
platform: '${platform}'
role: '${role}'
END
[ -n "$live" ] && destructive_chroot_cmd tee -a /etc/puppetlabs/facter/facts.d/nest.yaml <<END
live: true
END


task "Running Puppet..."
chroot_cmd puppet agent --onetime --verbose --no-daemonize --no-splay --show_diff --certname "$name" --server puppet.nest --logdir /var/log/puppet --rundir /var/run/puppet --vardir /var/lib/puppet --runtimeout 0
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
