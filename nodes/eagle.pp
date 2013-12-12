node 'eagle' {
    class { 'profile::base':
        disk_id          => 'ata-ST500LX003-1AC15G_W200AR6T',
        disk_mirror_id   => 'ata-WDC_WD5000BPKT-75PK4T0_WD-WXF1E32MVKS3',
        disk_profile     => cryptmirror,
        video_cards      => ['radeon'],
        package_server   => 'http://packages.thestaticvoid.com/',
        roles            => [
            desktop,
            virtualbox,
            work_system,
        ],
    }
}

@host { 'eagle':
    ip => '172.22.2.5',
}
