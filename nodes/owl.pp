node 'owl' {
    class { 'nest':
        boot_disk      => '/dev/disk/by-id/ata-Samsung_SSD_840_PRO_Series_S1ANNSADB32149W',
        boot_options   => 'nouveau.config=NvMSI=0',
        distcc         => true,
        video_cards    => ['nouveau'],
        dpi            => '96',
        package_server => 'http://hawk/packages/',
        roles          => [
            desktop,
            laptop,
            virtualbox,
        ],
    }

    crypt::device { '/dev/disk/by-id/ata-Samsung_SSD_840_PRO_Series_S1ANNSADB32149W-part4':
        target => 'rpool-crypt0',
        uuid   => '130a2231-d1a1-49f0-a8bb-7bc86036d6a9',
    }

    package_mask { 'x11-drivers/nvidia-drivers':
        version => '>=305.0.0'
    }
}

@openvpn::host { 'owl':
    ip => '172.22.2.3',
}

@sshkey { 'owl':
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBAO3/zWG4VQu9D8Sc48mWC8oAmjDWBecXVrfgV4as0BmNzubSXOZzN2BSCjGnnPr1l0Oijln+eRPbm1C4In2Gew2ZHIZbYGWHcMehJw68c+dsRsM+1Hb/nPLw6veGCdPoq0FvjBlfLx9Rb5S6xFN2oH/HfljI/q1ianFs9F2QMgrrAAAAFQCY4QflmsXMSW4H+tbzBhDubJXGCwAAAIAVtjKuOcT6Wt4G5/ABzJH0aqGAMD1/Nai74D3ydk5nYBxv/ydOwO0jAwBOApvM61N70vehX6krQcRH/NAaiXLIPtwgMiYyl11BSAuQKYjTr3tnpzgvPfsfmPjz+oJUgq/Fyqc/Rg+SVoa4usMXCjm6LOuh+wujgPZNnGnnUMcH3QAAAIEA0jj/hMMDgBb41OROG5He92b+GF/G3OLYqEcvcwU+7CkGkpCVdV2DiAEpY26Kw1vjYaR54moUIcRIZXvIrj7w5M5Uz6j40NCzXQvVzRdWaddmmjOHgvMCMbzh6Pk9R4GY8nVmAFgLIIpqEyXa1xaLWcIm+jmjSF87DL/KRO6CIZc=',
}
