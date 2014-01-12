node 'hawk' {
    class { 'profile::base':
        disk_id          => 'ata-Samsung_SSD_840_PRO_Series_S1ATNSAD907240P',
        disk_profile     => crypt,
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

    #
    # Miscellaneous firewall rules
    #
    iptables::accept { 'crashplan':
        port     => 4242,
        protocol => tcp,
    }

    iptables::accept { 'transmission':
        port     => 51413,
        protocol => tcp,
    }
}

@host { 'hawk':
    ip => '172.22.2.1',
}
