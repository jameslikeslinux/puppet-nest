node 'hawk' {
    class { 'profile::base':
        disk_path        => 'pci-0000:00:1f.2-scsi-1:0:0:0',
        disk_mirror_path => 'pci-0000:00:1f.2-scsi-2:0:0:0',
        disk_profile     => cryptmirror,
        video_cards      => ['nouveau'],
        dpi              => 192,
        lcd              => false,
        roles            => [
            desktop,
            lamp_server,
            package_server,
            private_stuff,
            puppet_dashboard,
            puppet_master,
            server,
            subsonic_server,
            thestaticvoid,
            vpn_server,
            web_server,
        ],
    }

    crypt::device { '/dev/disk/by-path/pci-0000:01:00.0-scsi-0:1:0:0':
        target   => 'nest-crypt0',
        keyfile  => '/dev/mapper/keyfile',
        bootdisk => false,
    }

    crypt::device { '/dev/disk/by-path/pci-0000:01:00.0-scsi-0:1:1:0':
        target   => 'nest-crypt1',
        keyfile  => '/dev/mapper/keyfile',
        bootdisk => false,
    }

    crypt::device { '/dev/disk/by-path/pci-0000:01:00.0-scsi-0:1:2:0':
        target   => 'nest-crypt2',
        keyfile  => '/dev/mapper/keyfile',
        bootdisk => false,
    }

    crypt::device { '/dev/disk/by-path/pci-0000:01:00.0-scsi-0:1:3:0':
        target   => 'nest-crypt3',
        keyfile  => '/dev/mapper/keyfile',
        bootdisk => false,
    }
}

@host { 'hawk':
    ip => '172.22.2.1',
}
