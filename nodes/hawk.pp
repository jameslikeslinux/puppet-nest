node 'hawk' {
    class { 'profile::base':
        disk_profile => cryptmirror,
        video_cards  => ['nouveau'],
        roles        => [
            desktop,
            lamp_server,
            package_server,
            private_stuff,
            puppet_master,
            thestaticvoid,
            vpn_server,
            web_server,
        ],
    }
}

@host { 'hawk':
    ip => '172.22.2.1',
}
