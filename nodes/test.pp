node 'test' {
    class { 'profile::base':
        disk_profile => cryptmirror,
        resolution   => '1024x768',
        video_cards  => ['cirrus'],
        roles        => [
            desktop,
        ],
    }
}

@host { 'test':
    ip => '172.22.2.2',
}
