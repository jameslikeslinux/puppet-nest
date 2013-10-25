node 'hawk' {
    class { 'profile::base':
        disk_id          => 'ata-ST3400620NS_5QH09PCG',
        disk_mirror_id   => 'ata-ST3400620AS_5QH09K6R',
        disk_profile     => cryptmirror,
        video_cards      => ['nouveau'],
        dpi              => 192,
        lcd              => false,
        roles            => [
            compile_server,
            desktop,
            lamp_server,
            nest,
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

    crypt::device { '/dev/disk/by-id/scsi-1ATA_ST2000DL003-9VT166_5YD03B5A':
        target   => 'nest-crypt0',
        keyfile  => '/dev/mapper/keyfile',
        bootdisk => false,
    }

    crypt::device { '/dev/disk/by-id/scsi-1ATA_ST2000DL003-9VT166_5YD23E8Q':
        target   => 'nest-crypt1',
        keyfile  => '/dev/mapper/keyfile',
        bootdisk => false,
    }

    crypt::device { '/dev/disk/by-id/scsi-1ATA_ST2000DL003-9VT166_5YD15L2S':
        target   => 'nest-crypt2',
        keyfile  => '/dev/mapper/keyfile',
        bootdisk => false,
    }

    crypt::device { '/dev/disk/by-id/scsi-1ATA_ST2000DL003-9VT166_5YD3VZQP':
        target   => 'nest-crypt3',
        keyfile  => '/dev/mapper/keyfile',
        bootdisk => false,
    }
}

@host { 'hawk':
    ip => '172.22.2.1',
}
