node 'falcon' {
    class { 'profile::base':
        disk_path        => 'pci-0000:00:1f.2-scsi-1:0:0:0',
        disk_mirror_path => 'pci-0000:00:1f.2-scsi-2:0:0:0',
        disk_profile     => cryptmirror,
        video_cards      => ['nouveau'],
        package_server   => 'http://packages.thestaticvoid.com/',
        roles            => [
            desktop,
            terminal_client,
            virtualbox,
        ],
    }
}

@host { 'falcon':
    ip => '172.22.2.4',
}
