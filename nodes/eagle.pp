node 'eagle' {
    class { 'nest':
        boot_disk          => ['EFI1', 'EFI2'],
        resolution         => native,
        default_sound_card => 'Audio',  # see /proc/asound/cards
        distcc             => true,
        keymap             => 'us',
        mouse              => 'mxmaster',
        package_server     => 'http://hawk/packages/',
        video_cards        => ['radeon'],
        wan                => true,
        roles              => [
            cachefiles,
            desktop,
            virtualbox,
            work_system,
        ],
    }

    crypt::device { '/dev/disk/by-id/ata-ST500LX003-1AC15G_W200AR6T-part3':
        target => 'rpool-crypt0',
        uuid   => '801a9021-19d8-40f6-b7ee-3c5a077307d2',
    }

    crypt::device { '/dev/disk/by-id/ata-WDC_WD5000BPKT-75PK4T0_WD-WXF1E32MVKS3-part3':
        target => 'rpool-crypt1',
        uuid   => '0e3b9ff3-31d2-4717-a1e0-4b46fb8e6fa8',
    }

    class { 'inkscape': }
}

@openvpn::host { 'eagle':
    ip => '172.22.2.5',
}

@sshkey { 'eagle':
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBAMZU9gTnM1az5xpoWfti1jlCZcutjpVjGgbocO6ry82sQdPZeG7Vzk/rF6ONVafLPpMTOmOTa7+rbVniFrTlUFjCmHv6Grmp6OLXwA21HPRJnzoY7SQC2Q2Vy2mNYiMTEhrg6gEO7slGhOTYkKEw5oWBxe8S61kf+rMC2Mc+6V3XAAAAFQCBKBrPsMrHmVsavzF/tK5suhHZ1wAAAIB9oCUsbZCRnFlgPWRCJYjgH8IQGJ/fM8PhhZiK1OJTnv16iCTPOFQj+OdaooKlPd6jGwEDKdHdSQJM+OoM6D9w9gR7yLZIHchptRb2GdW6U9oo3ydQkwE5ZmDRhbRQJubQ4wzWQ1P8j6xJpCKsKdkxToK9BGebvSgbYBS7Abv6bgAAAIEAikexjZeiCTPZwzrO7AoCQ/ib8ZmsMXB/RGPInetxokuSMEf7s+DMdBtTx/OsYAOANTcFdFeSuVDryc7IigXF+EYafsQFpmbL+bjiBOsix69HJO7IEaqdp5o66GTg7FhNEsApkLaPzz04/c+dVIcHqaySRrdDHvB7Ykj/7EdlkmE=',
}

@cups::browse { 'eagle': }
