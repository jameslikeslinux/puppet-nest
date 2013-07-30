node 'hawk' {
    class { 'base_role': }

    class { 'mirror_crypt_role': }

    class { 'desktop_role':
        video_cards => ['nouveau'],
    }

    class { 'ssh::server':
        port => 2225,
    }
}
