class iptables {
    portage::package { 'net-firewall/iptables':
        ensure => installed,
    }


    #
    # Don't overwrite Puppet rules on service shutdown
    #
    file { '/etc/conf.d/iptables':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/iptables/iptables.conf',
        require => Portage::Package['net-firewall/iptables'],
        notify  => Openrc::Service['iptables'],
    }

    file { '/etc/conf.d/ip6tables':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/iptables/ip6tables.conf',
        require => Portage::Package['net-firewall/iptables'],
        notify  => Openrc::Service['ip6tables'],
    }


    #
    # Concatenate rules together
    #
    concat { 'iptables-rules':
        path    => '/var/lib/iptables/rules-save',
        require => Portage::Package['net-firewall/iptables'],
        notify  => Openrc::Service['iptables'],
    }

    concat { 'ip6tables-rules':
        path    => '/var/lib/ip6tables/rules-save',
        require => Portage::Package['net-firewall/iptables'],
        notify  => Openrc::Service['ip6tables'],
    }


    #
    # Enable the service
    #
    openrc::service { 'iptables':
        enable  => true,
        require => File['/etc/conf.d/iptables'],
    }

    openrc::service { 'ip6tables':
        enable  => true,
        require => File['/etc/conf.d/ip6tables'],
    }


    #
    # Establish default rules
    #
    concat::fragment { 'iptables-header':
        target  => 'iptables-rules',
        content => template('iptables/filter-header.erb'),
        order   => '00',
    }

    concat::fragment { 'ip6tables-header':
        target  => 'ip6tables-rules',
        content => template('iptables/filter-header.erb'),
        order   => '00',
    }

    iptables::accept { 'loopback':
        device => 'lo',
    }

    iptables::accept { 'pingv4':
        protocol => icmp,
        port     => 8,
        l3prot   => v4,
    }

    iptables::accept { 'pingv6':
        protocol => icmpv6,
        port     => 128,
        l3prot   => v6,
    }

    iptables::rule { 'accept-established-and-related':
        rule  => '-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT',
        order => '10',
    }

    iptables::rule { 'log':
        rule  => '-A INPUT -m limit --limit 5/m --limit-burst 10 -j LOG',
        order => '47',
    }

    iptables::rule { 'drop':
        rule  => '-A INPUT -j DROP',
        order => '48',
    }

    iptables::rule { 'commit':
        rule  => 'COMMIT',
        order => '49',
    }
}
