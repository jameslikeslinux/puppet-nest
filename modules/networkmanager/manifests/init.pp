class networkmanager (
    $kde         = false,
    $openconnect = false,
) {
    portage::package { 'net-misc/networkmanager':
        ensure => installed,
        unmask => '=0.9.8.2',
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

        portage::package { 'kde-misc/networkmanagement':
            ensure  => installed,
            use     => $use_openconnect,
            require => Portage::Package['net-misc/networkmanager'],
        }
    }

    if $openconnect {
        portage::package { 'net-misc/networkmanager-openconnect':
            ensure  => installed,
            require => Portage::Package['net-misc/networkmanager'],
        }
    }
}
