class profile::role::cups {
    class { 'nsswitch':
        avahi => true,
    }

    class { '::cups':
        kde   => true,
        avahi => true,
    }

    iptables::accept { 'avahi':
        port     => 5353,
        protocol => udp,
    }
}
