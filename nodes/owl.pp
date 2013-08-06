node 'owl' {
    class { 'profile::base':
        disk_profile   => crypt,
        video_cards    => ['nouveau'],
        package_server => 'http://packages.thestaticvoid.com/',
        roles          => [
            desktop,
            laptop,
        ],
    }
}

@host { 'owl':
    ip => '172.22.2.3',
}
