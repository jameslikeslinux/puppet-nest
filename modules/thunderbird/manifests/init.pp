class thunderbird {
    portage::package { 'app-crypt/pinentry':
        ensure => 'installed',
        use    => 'gtk',
    }

    portage::package { 'mail-client/thunderbird':
        ensure  => 'installed',
        use     => ['gstreamer', 'ldap', 'libnotify', 'startup-notification'],
        require => Portage::Package['app-crypt/pinentry'],
    }
}
