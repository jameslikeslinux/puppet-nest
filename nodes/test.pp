node 'test' {
    class { 'profile::base':
        disk_path        => 'pci-0000:00:06.0-scsi-0:0:0:0',
        disk_mirror_path => 'pci-0000:00:06.0-scsi-1:0:0:0',
        disk_profile     => cryptmirror,
        resolution       => '1024x768',
        video_cards      => ['cirrus'],
        package_server   => 'http://packages.thestaticvoid.com/',
        roles            => [
            desktop,
        ],
    }
}

@host { 'test':
    ip => '172.22.2.2',
}
