node 'owl' {
    class { 'profile::base':
        disk_path      => 'pci-0000:00:1f.2-scsi-0:0:0:0',
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
