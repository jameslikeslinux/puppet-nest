class thunderbird {
    include pinentry

    portage::package { 'mail-client/thunderbird':
        ensure  => installed,
        use     => ['gstreamer', 'ldap', 'libnotify', 'startup-notification'],
        require => Class['pinentry'],
    }
}
