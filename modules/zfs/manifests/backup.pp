class zfs::backup (
    $remote_host    = undef,
    $remote_dataset = undef,
) {
    $home = '/var/lib/zfssnap'

    group { 'zfssnap':
        gid => '500',
    }

    users::user { 'zfssnap':
        uid            => '500',
        gid            => 'zfssnap',
        groups         => ['cron'],
        fullname       => 'ZFS Auto Snapshot',
        shell          => '/bin/zsh',
        home           => $home,
        profile        => 'https://github.com/MrStaticVoid/zfssnap.git',
        ssh_key_source => 'puppet:///modules/private/zfs/backup/id_rsa',
        require        => [
            Class['cronie'],
            Class['zsh'],
        ],
    }

    sudo::conf { 'zfssnap':
        content => 'zfssnap ALL=NOPASSWD: /sbin/zfs, /sbin/zpool',
    }

    Cron {
        user        => 'zfssnap',
        environment => [
            "PATH=${home}/bin:/usr/bin:/bin",
            'MAILTO=root',
        ],
    }

    cron { 'zfs-auto-snapshot-frequent':
        command => 'zfs-auto-snapshot --quiet --syslog --label=frequent --keep=4 // 2>&1 | grep -v "dataset is busy"',
        minute  => '*/15',
    }

    cron { 'zfs-auto-snapshot-hourly':
        command => 'zfs-auto-snapshot --quiet --syslog --label=hourly --keep=24 // 2>&1 | grep -v "dataset is busy"',
        special => 'hourly',
    }

    cron { 'zfs-auto-snapshot-daily':
        command => 'zfs-auto-snapshot --quiet --syslog --label=daily --keep=31 // 2>&1 | grep -v "dataset is busy"',
        special => 'daily',
    }

    cron { 'zfs-auto-snapshot-weekly':
        command => 'zfs-auto-snapshot --quiet --syslog --label=weekly --keep=8 // 2>&1 | grep -v "dataset is busy"',
        special => 'weekly',
    }

    cron { 'zfs-auto-snapshot-monthly':
        command => 'zfs-auto-snapshot --quiet --syslog --label=monthly --keep=12 // 2>&1 | grep -v "dataset is busy"',
        special => 'monthly',
    }

    if $remote_host and $remote_dataset {
        file { "${home}/zfs-backup.cfg":
            mode    => '0644',
            owner   => 'zfssnap',
            group   => 'zfssnap',
            content => template('zfs/zfs-backup.cfg.erb'),
            require => Users::User['zfssnap'],
        }

        cron { 'zfs-backup':
            command => 'zfs-backup 2>&1 | grep -v WARNING',
            minute  => '0',
            hour    => '1',
            require => File["${home}/zfs-backup.cfg"],
        }
    }
}
