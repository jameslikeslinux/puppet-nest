class openvpn {
    portage::package { 'net-misc/openvpn':
        ensure => installed,
    }
}
