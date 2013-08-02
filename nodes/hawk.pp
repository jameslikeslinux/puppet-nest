node 'hawk.thestaticvoid.com' {
    class { 'profile::base':
        disk_profile => cryptmirror,
        video_cards  => ['nouveau'],
        roles        => [
            desktop,
            package_server,
            puppet_master,
            vpn_server,
        ],
    }
}
