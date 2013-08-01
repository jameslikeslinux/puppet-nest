node 'hawk.thestaticvoid.com' {
    class { 'profile::base':
        disk_profile   => cryptmirror,
        desktop        => true,
        package_server => 'http://pkg.thestaticvoid.com/packages',
    }

    class { 'role::desktop':
        video_cards => ['nouveau'],
    }
}
