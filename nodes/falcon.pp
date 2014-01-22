node 'falcon' {
    class { 'profile::base':
        disk_id          => 'ata-Samsung_SSD_840_PRO_Series_S1ATNSAD908564X',
        disk_profile     => crypt,
        video_cards      => ['nouveau'],
        package_server   => 'http://packages.thestaticvoid.com/',
        roles            => [
            desktop,
            qemu_chroot,
            terminal_client,
            virtualbox,
            work_system,
        ],
    }

    class { 'inkscape': }
}

@host { 'falcon':
    ip => '172.22.2.4',
}
