node 'hawk' {
    class { 'profile::base':
        remote_backup    => true,
        disk_id          => '/dev/disk/by-id/ata-Samsung_SSD_840_PRO_Series_S1ATNSAD907240P-part',
        disk_profile     => crypt,
        keymap           => 'dvorak',
        video_cards      => ['nvidia'],
        video_options    => {'metamodes' => 'DVI-I-2: nvidia-auto-select +1680+0, DVI-I-3: nvidia-auto-select +0+0'},
        roles            => [
            compile_server,
            desktop,
            #lamp_server,
            nest,
            package_server,
            private_stuff,
            #puppet_dashboard,
            puppet_master,
            qemu_chroot,
            server,
            subsonic_server,
            terminal_client,
            virtualbox,
            vpn_server,
            web_server,
            #work_system,
        ],
    }

    crypt::device { '/dev/disk/by-id/scsi-1ATA_ST2000DM001-1CH164_Z1E59EN3':
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

    crypt::device { '/dev/disk/by-id/ata-ST3400620NS_5QH0BMKB':
        target   => 'archive-crypt0',
        keyfile  => '/dev/mapper/keyfile',
        bootdisk => false,
    }

    crypt::device { '/dev/disk/by-id/ata-ST3400620NS_5QH0BMW1':
        target   => 'archive-crypt1',
        keyfile  => '/dev/mapper/keyfile',
        bootdisk => false,
    }

    crypt::device { '/dev/disk/by-id/ata-ST3400620AS_5QH09K6R':
        target   => 'archive-crypt2',
        keyfile  => '/dev/mapper/keyfile',
        bootdisk => false,
    }

    package_mask { 'x11-drivers/nvidia-drivers':
        version => '>=341.0.0'
    }

    class { 'inkscape': }

    #
    # System uses snd_ctxfi.
    # Disable on-board sound so I don't have to figure out
    # how to prioritize one over the other.
    #
    kernel::modules::blacklist { 'snd_hda_intel': }

    #
    # Allow SSH for access to VPN.  This is OK...
    # password authentication is DISABLED.
    #
    iptables::accept { 'ssh':
        port     => 22,
        protocol => tcp,
    }

    #
    # Allow multicast for Chromecast support
    #
    class { 'iptables::multicast': }

    #
    # Create VPN profiles for phone and tablet
    #
    openvpn::mobile { [
        'm8',
        'nexus7',
    ]: }
}

@host { 'hawk':
    ip => '172.22.2.1',
}

@sshkey { 'hawk':
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBAIEmwKhaBY1AIKUqqbGEEeHzALhx0qnuuqqPVkE3OabL8wv5fSczGsCltou2fOxP5skaKG15qDw4e7Q96qt4JA2J4STmMTTosuLuE+XwlGD9pNkv+KNMcpPOzLDZ24jx77smjuswg6Ij7vYPwDUQL4EQqtdYXpXK0Cg5qnWCkeIFAAAAFQDhZCDDU12OVam85hDNTSl6GXMeXQAAAIBTAlOo337b3zO8qlVaVrunx65LLlM2iK9viWNKLB46lsK61BlOVGLIj37rM16XsGWzl3SNxG7QKhXwi06Gx2kFEABPx42xTRYeqLyqAYHehFTStEVUeVFJD43kcH32VEyzI7y0w158jf/80yYheI5UVCt3Lasu60AOXChRmq5pmAAAAIBUlAMeCTFBJ+Qcszm/UwIXOv+ezBra5X5XbAwJhsFeCioTUo9X2GaHbYgZOk3cDgk+wXeuRwv4hn9tYTyhUokCIn4wIPQihMGVXtagFcEp49gPg12DjcdAdDejPsvwh7q0zKMQLqdrn9ULbURbulxPOUCDZ1Jom42bDzVebVyG9Q==',
}

@cups::browse { 'hawk': }

@host { 'm8':
    ip => '172.22.2.10',
}
