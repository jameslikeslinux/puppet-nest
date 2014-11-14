class pidgin {
    package_use { [
        'net-libs/libsoup',
        'net-libs/gssdp',
    ]:
        use    => 'introspection',
        before => Portage::Package['net-im/pidgin'],
    }

    portage::package { 'net-im/pidgin':
        ensure => installed,
        use    => ['gtk', 'spell'],
    }
}
