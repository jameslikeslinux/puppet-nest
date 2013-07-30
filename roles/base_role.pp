class base_role {
    class { 'makeconf': }

    fstab::fs { 'boot':
        device     => '/dev/sda1',
        mountpoint => '/boot',
        type       => 'ext2',
        options    => 'noatime',
        dump       => 1,
        pass       => 2
    }

    fstab::fs { 'swap':
        device     => '/dev/zvol/rpool/swap',
        mountpoint => 'none',
        type       => 'swap',
        options    => 'sw',
    }

    dracut::conf { 'devices':
        boot_devices => ['/dev/sda3'],
    }

    class { 'kernel': }

    class { 'zfs': }

    class { 'plymouth': }

    grub::install { '/dev/sda': }

    class { 'boot':
        default_entry => 'Funtoo Linux',
    }

    boot::entry { 'Funtoo Linux':
        kernel  => 'kernel[-v]',
        initrd  => 'initramfs[-v]',
        root    => 'zfs',
        params  => ['quiet', 'splash'],
    }

    class { 'keymaps':
        keymap => 'dvorak',
    }

    file { '/etc/localtime':
        ensure => link,
        target => '/usr/share/zoneinfo/America/New_York',
    }

    file { '/etc/motd':
        ensure => absent,
    }

    class { 'zsh': }

    users::user { 'jlee':
        uid         => 1000,
        groups      => ['wheel'],
        fullname    => 'James Lee',
        shell       => '/bin/zsh',
        zfs_dataset => 'rpool/home/jlee',
        profile     => 'git://github.com/MrStaticVoid/profile.git',
        require     => Class['zsh'],
    }

    #
    # For better or worse, my root identity is the the same as my
    # personal identity.
    #
    file { '/root/.ssh':
        ensure  => directory,
        owner   => 'root',
        group   => 'root',
        source  => '/home/jlee/.ssh',
        recurse => true,
        require => Users::User['jlee']
    }

    class { 'sudo': }

    sudo::conf { 'wheel':
        content => '%wheel ALL=(ALL) NOPASSWD: ALL',
    }

    exec { '/usr/bin/passwd --lock root':
        unless => '/usr/bin/passwd --status root | /bin/grep " L "',
    }

    class { 'vim': }

    class { 'kerberos': }

    class { 'ssh': }

    class { 'rsyslog': }

    class { 'cronie': }

    class { 'ntp': }

    #
    # Install miscellaneous packages.
    #
    portage::package { [
        'net-misc/netkit-telnetd',
        'sys-process/glances',
        'dev-util/strace',
        'net-dns/bind-tools',
    ]:
        ensure => installed,
    }
}
