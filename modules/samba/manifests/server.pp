class samba::server (
    $workgroup = 'WORKGROUP',
) {
    include samba

    concat { '/etc/samba/smb.conf':
        require => Class['samba'],
        notify  => Openrc::Service['samba'],
    }

    concat::fragment { 'smb.conf-head':
        order   => '00',
        content => template('samba/smb.conf.erb'),
        target  => '/etc/samba/smb.conf',
    }

    openrc::service { 'samba':
        enable  => true,
        require => Concat['/etc/samba/smb.conf'],
    }

    iptables::accept { 'samba':
        port     => 445,
        protocol => tcp,
    }
}
