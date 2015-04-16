node 'hawk' {
    class { 'nest':
        remote_backup    => true,
        boot_disk        => '/dev/disk/by-id/ata-Samsung_SSD_840_PRO_Series_S1ATNSAD907240P',
        boot_decrypt     => ['36e9ffb7-5c41-4d4f-87c0-ec63db1f7595', '832a64c4-30f0-469a-af11-f88afb2dfa65', '076a3d01-ef73-4436-88f7-e02e05859451', 'a5103dd3-6b47-41d4-bc7a-5c1c675dfa2f', '2d708e8a-4e54-47de-8af4-430979d06cda', '234b6c5d-5ab4-4570-a2d3-a1e96f0a8a25', '0eec27a2-0ae7-48e0-bba4-6334171a95f1', '5c7d5184-c217-4716-a7e8-bd418945962b'],
        boot_options     => ['intel_iommu=on', 'pci-stub.ids=10de:0fbc,1b21:1142'],
        keymap           => 'us',
        video_cards      => ['nvidia'],
        video_options    => {'metamodes' => 'DP-3: nvidia-auto-select +2560+0, DP-2: nvidia-auto-select +0+0', 'nvidiaXineramaInfoOrder' => 'DFP-4'},
        roles            => [
            compile_server,
            desktop,
            kvm_hypervisor,
            #lamp_server,
            nest_server,
            package_server,
            private_stuff,
            #puppet_dashboard,
            puppet_master,
            qemu_chroot,
            server,
            subsonic_server,
            synergy_server,
            terminal_client,
            vpn_server,
            web_server,
            #work_system,
        ],
    }

    package_mask { 'x11-drivers/nvidia-drivers':
        version => '>=341.0.0',
        ensure  => absent,
    }

    class { 'inkscape': }

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

    dracut::conf { 'pci-stub':
        force_drivers => ['pci-stub'],
    }

    #
    # Disable intel audio for now
    #
    kernel::modules::blacklist { 'snd-hda-intel': }
}

@hostname::host { 'hawk':
    ip => '172.22.2.1',
}

@sshkey { 'hawk':
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBAIEmwKhaBY1AIKUqqbGEEeHzALhx0qnuuqqPVkE3OabL8wv5fSczGsCltou2fOxP5skaKG15qDw4e7Q96qt4JA2J4STmMTTosuLuE+XwlGD9pNkv+KNMcpPOzLDZ24jx77smjuswg6Ij7vYPwDUQL4EQqtdYXpXK0Cg5qnWCkeIFAAAAFQDhZCDDU12OVam85hDNTSl6GXMeXQAAAIBTAlOo337b3zO8qlVaVrunx65LLlM2iK9viWNKLB46lsK61BlOVGLIj37rM16XsGWzl3SNxG7QKhXwi06Gx2kFEABPx42xTRYeqLyqAYHehFTStEVUeVFJD43kcH32VEyzI7y0w158jf/80yYheI5UVCt3Lasu60AOXChRmq5pmAAAAIBUlAMeCTFBJ+Qcszm/UwIXOv+ezBra5X5XbAwJhsFeCioTUo9X2GaHbYgZOk3cDgk+wXeuRwv4hn9tYTyhUokCIn4wIPQihMGVXtagFcEp49gPg12DjcdAdDejPsvwh7q0zKMQLqdrn9ULbURbulxPOUCDZ1Jom42bDzVebVyG9Q==',
}

@cups::browse { 'hawk': }

@hostname::host { 'm8':
    ip => '172.22.2.10',
}
