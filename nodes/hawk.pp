node 'hawk' {
    class { 'profile::base':
        disk_profile => cryptmirror,
        desktop      => true,
    }

    class { 'role::desktop':
        video_cards => ['nouveau'],
    }
}
