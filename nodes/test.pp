node 'test' {
    class { 'base_role': 
        gfxmode => '1024x768',
    }

    class { 'mirror_crypt_role': }

    class { 'desktop_role':
        video_cards => ['cirrus'],
    }

    class { 'ssh::server':
        port => 22,
    }
}
