class cpupower (
    $governor,
) {
    portage::package { 'sys-power/cpupower':
        ensure => installed,
    }

    file { '/etc/conf.d/cpupower':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('cpupower/confd.erb'),
        require => Portage::Package['sys-power/cpupower'],
        notify  => Openrc::Service['cpupower'],
    }

    openrc::service { 'cpupower':
        enable => true,
    }
}
