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

    iptables::rule { 'accept-loopback':
        rule  => '-A INPUT -i lo -j ACCEPT',
        order => '01',
    }

    iptables::rule { 'accept-icmpv6':
        rule   => '-A INPUT -p icmpv6 -j ACCEPT',
        order  => '05',
        l3prot => v6,
    }

    iptables::accept { 'pingv4':
        protocol => icmp,
        port     => 8,
        l3prot   => v4,
    }

    iptables::rule { 'accept-established-and-related':
        rule  => '-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT',
        order => '10',
    }

    iptables::rule { 'drop-broadcast-before-log':
        rule   => '-A INPUT -m pkttype --pkt-type broadcast -j DROP',
        order  => '46',
    }

    iptables::rule { 'drop-multicast-before-log':
        rule   => '-A INPUT -m pkttype --pkt-type multicast -j DROP',
        order  => '46',
    }

    iptables::rule { 'logv4':
        rule   => '-A INPUT -m limit --limit 5/m --limit-burst 10 -j LOG --log-prefix="iptables: DROP "',
        order  => '47',
        l3prot => v4,
    }

    iptables::rule { 'logv6':
        rule   => '-A INPUT -m limit --limit 5/m --limit-burst 10 -j LOG --log-prefix="ip6tables: DROP "',
        order  => '47',
        l3prot => v6,
    }

    iptables::rule { 'drop':
        rule  => '-A INPUT -j DROP',
        order => '48',
    }

    concat::fragment { 'iptables-filter-footer':
        target  => 'iptables-rules',
        content => "COMMIT\n",
        order   => '49',
    }

    concat::fragment { 'ip6tables-footer':
        target  => 'ip6tables-rules',
        content => "COMMIT\n",
        order   => '49',
    }
}
