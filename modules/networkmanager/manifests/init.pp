class networkmanager (
    $kde = false,
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
        portage::package { 'kde-misc/networkmanagement':
            ensure  => installed,
            require => Portage::Package['net-misc/networkmanager'],
        }
    }
}
