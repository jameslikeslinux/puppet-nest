define autofs::map (
    $key,
    $options  = undef,
) {
    $location = "/etc/autofs/auto.${name}"

    concat::fragment { "auto.master-map-${name}":
        target  => '/etc/autofs/auto.master',
        content => template('autofs/map.erb'),
    }

    concat { $location:
        require => Portage::Package['net-fs/autofs'],
        notify  => Openrc::Service['autofs'],
    }

    concat::fragment { "${location}-header":
        target => $location,
        source => 'puppet:///modules/autofs/auto.map',
        order  => '00',
    }
}
