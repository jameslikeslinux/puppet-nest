node 'test' {
    class { 'profile::base':
        disk_profile   => cryptmirror,
        resolution     => '1024x768',
        video_cards    => ['cirrus'],
        package_server => 'http://packages.thestaticvoid.com/',
        roles          => [
            desktop,
        ],
    }
}

@host { 'test':
    ip => '172.22.2.2',
}
