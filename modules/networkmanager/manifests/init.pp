class networkmanager (
    $kde         = false,
    $openconnect = false,
) {
    portage::package { 'net-misc/networkmanager':
        use            => $openconnect ? {
            true    => ['wifi', 'plugins_openconnect'],
            default => ['wifi'],
        },
        ensure         => installed,
    }

    openrc::service { 'NetworkManager':
        enable  => true,
        require => Portage::Package['net-misc/networkmanager'],
    }

    if $kde {
        $use_openconnect = $openconnect ? {
            true    => ['openconnect'],
            default => [],
        }

        portage::package { 'kde-plasma/plasma-nm':
            use     => $use_openconnect,
            require => Portage::Package['net-misc/networkmanager'],
        }
    }

    if $openconnect {
        include pinentry
        include openconnect

        package_use { 'app-crypt/gcr':
            use => 'gtk',
            before => Portage::Package['net-misc/networkmanager-openconnect'],
        }

        portage::package { 'net-misc/networkmanager-openconnect':
            ensure  => installed,
            require => [
                Portage::Package['net-misc/networkmanager'],
                Class['pinentry'],
                Class['openconnect'],
            ],
        }
    }
}
