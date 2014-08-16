class profile::base::environment {
    $is_puppet_master = puppet_master in $profile::base::roles
    $is_vpn_server = vpn_server in $profile::base::roles

    if $is_puppet_master and $is_vpn_server {
        $dns_alt_names = ['puppet.thestaticvoid.com', 'vpn.thestaticvoid.com']
    } elsif $is_puppet_master {
        $dns_alt_names = ['puppet.thestaticvoid.com']
    } elsif $is_vpn_server {
        $dns_alt_names = ['vpn.thestaticvoid.com']
    } else {
        $dns_alt_names = undef
    }

    #
    # Is a Puppet agent.
    #
    class { 'puppet::agent':
        master        => 'puppet.thestaticvoid.com',
        certname      => $clientcert,
        dns_alt_names => $dns_alt_names,
    }


    #
    # Uses a Dvorak keyboard.
    #
    class { 'keymaps':
        keymap => $profile::base::keymap,
    }


    #
    # Is on the east coast of the US.
    #
    file { '/etc/localtime':
        ensure => link,
        target => "/usr/share/zoneinfo/${profile::base::timezone}",
    }


    #
    # Has nothing to announce.
    #
    file { '/etc/motd':
        ensure => absent,
    }


    #
    # Can use Kerberos to connect to UMD machines.
    #
    class { 'kerberos':
        default_realm => 'UMD.EDU'
    }


    #
    # Can authenticate against SSH keys and get Kerberos tickets
    #
    class { 'pam':
        ssh     => true,
        krb5    => true,
        require => Class['kerberos'],
    }


    #
    # Has more reasonable swappiness value (default is 60)
    #
    sysctl { 'vm.swappiness':
        value => '10',
    }
}
