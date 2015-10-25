class pinentry {
    # required by gnome-base/gnome-keyring-3.16.0-r1::gentoo
    # required by app-crypt/libsecret-0.18.3::gentoo
    # required by net-misc/networkmanager-openconnect-1.0.2::gentoo
    package_use { 'app-crypt/pinentry':
        use => ['gnome-keyring', 'gtk'],
    }
}
