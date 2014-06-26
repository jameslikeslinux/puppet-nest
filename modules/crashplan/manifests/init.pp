class crashplan {
    file { '/etc/init.d/crashplan':
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/crashplan/crashplan.init',
    }

    openrc::service { 'crashplan':
        enable  => true,
        require => File['/etc/init.d/crashplan'],
    }

    iptables::accept { 'crashplan':
        port     => 4242,
        protocol => tcp,
    }
}
