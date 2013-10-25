node 'falcon' {
    class { 'profile::base':
        disk_id          => 'ata-ST3400620NS_5QH0BMKB',
        disk_mirror_id   => 'ata-ST3400620NS_5QH0BMW1',
        disk_profile     => cryptmirror,
        video_cards      => ['nouveau'],
        package_server   => 'http://packages.thestaticvoid.com/',
        roles            => [
            desktop,
            qemu_chroot,
            terminal_client,
            virtualbox,
        ],
    }
}

@host { 'falcon':
    ip => '172.22.2.4',
}
