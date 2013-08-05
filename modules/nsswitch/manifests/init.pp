class nsswitch (
    $avahi = false,
) {
    $hosts = $avahi ? {
        false   => 'files dns',
        default => 'files mdns_minimal [NOTFOUND=return] dns',
    }

    if $avahi {
        portage::package { 'sys-auth/nss-mdns':
            ensure => installed,
        }
    }

    file { '/etc/nsswitch.conf':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('nsswitch/nsswitch.conf.erb'),
        require => $avahi ? {
            false   => undef,
            default => Portage::Package['sys-auth/nss-mdns'],
        }
    }
}
