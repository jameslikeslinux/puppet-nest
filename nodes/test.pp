node 'test' {
    class { 'profile::base':
        disk_profile       => cryptmirror,
        console_resolution => '1024x768',
        desktop            => true,
    }

    class { 'role::desktop':
        video_cards => ['cirrus'],
    }

    class { 'role::web_server': }
}
