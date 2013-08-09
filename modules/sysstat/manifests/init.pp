class sysstat (
    $sar = false,
) {
    portage::package { 'app-admin/sysstat':
        ensure => installed,
        use    => $sar ? {
            false   => undef,
            default => 'cron',
        },
    }

    if $sar {
        openrc::service { 'sysstat':
            enable => true,
        }

        cron { 'sar':
            command => '/usr/lib/sa/sa1 1 1',
            user    => 'root',
            minute  => '*/10',
        }
    }
}
