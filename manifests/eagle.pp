node 'eagle' {
    class { 'profile::base':
        boot_disk        => ['/dev/disk/by-id/ata-ST500LX003-1AC15G_W200AR6T', '/dev/disk/by-id/ata-WDC_WD5000BPKT-75PK4T0_WD-WXF1E32MVKS3'],
        boot_decrypt     => ['2709cb06-be97-49a0-83f2-aaf06a41ca4b', 'beb00b1a-123d-4bed-8d3c-9d72e415a144'],
        keymap           => 'us',
        video_cards      => ['radeon'],
        package_server   => 'http://hawk/packages/',
        wan              => true,
        roles            => [
            cachefiles,
            desktop,
            virtualbox,
            work_system,
        ],
    }

    class { 'inkscape': }

    #
    # System uses snd_usb
    # Disable on-board sound so I don't have to figure out
    # how to prioritize one over the other.
    #
    kernel::modules::blacklist { 'snd_hda_intel': }
}

@hostname::host { 'eagle':
    ip => '172.22.2.5',
}

@sshkey { 'eagle':
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBAMZU9gTnM1az5xpoWfti1jlCZcutjpVjGgbocO6ry82sQdPZeG7Vzk/rF6ONVafLPpMTOmOTa7+rbVniFrTlUFjCmHv6Grmp6OLXwA21HPRJnzoY7SQC2Q2Vy2mNYiMTEhrg6gEO7slGhOTYkKEw5oWBxe8S61kf+rMC2Mc+6V3XAAAAFQCBKBrPsMrHmVsavzF/tK5suhHZ1wAAAIB9oCUsbZCRnFlgPWRCJYjgH8IQGJ/fM8PhhZiK1OJTnv16iCTPOFQj+OdaooKlPd6jGwEDKdHdSQJM+OoM6D9w9gR7yLZIHchptRb2GdW6U9oo3ydQkwE5ZmDRhbRQJubQ4wzWQ1P8j6xJpCKsKdkxToK9BGebvSgbYBS7Abv6bgAAAIEAikexjZeiCTPZwzrO7AoCQ/ib8ZmsMXB/RGPInetxokuSMEf7s+DMdBtTx/OsYAOANTcFdFeSuVDryc7IigXF+EYafsQFpmbL+bjiBOsix69HJO7IEaqdp5o66GTg7FhNEsApkLaPzz04/c+dVIcHqaySRrdDHvB7Ykj/7EdlkmE=',
}

@cups::browse { 'eagle': }
