class profile::base::environment {
    #
    # Is a Puppet agent.
    #
    class { 'puppet::agent':
        master => 'puppet.thestaticvoid.com',
    }


    #
    # Uses a Dvorak keyboard.
    #
    class { 'keymaps':
        keymap => 'dvorak',
    }


    #
    # Is on the east coast of the US.
    #
    file { '/etc/localtime':
        ensure => link,
        target => '/usr/share/zoneinfo/America/New_York',
    }


    #
    # Has nothing to announce.
    #
    file { '/etc/motd':
        ensure => absent,
    }
}
