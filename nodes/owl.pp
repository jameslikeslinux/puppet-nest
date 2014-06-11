node 'owl' {
    class { 'profile::base':
        disk_id        => '/dev/disk/by-id/ata-Samsung_SSD_840_PRO_Series_S1ANNSADB32149W-part',
        disk_profile   => crypt,
        video_cards    => ['nouveau'],
        package_server => 'http://hawk/packages/',
        roles          => [
            desktop,
            laptop,
        ],
    }
}

@host { 'owl':
    ip => '172.22.2.3',
}
