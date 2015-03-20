class synergy::server {
    include synergy

    iptables::accept { 'synergy':
        port     => 24800,
        protocol => tcp,
    }

    file { '/etc/X11/xinit/xinitrc.d/99-synergy':
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/synergy/xinit.sh',
    }
}
