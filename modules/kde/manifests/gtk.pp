class kde::gtk {
    portage::package { [
        'x11-themes/oxygen-gtk',
        'kde-misc/kde-gtk-config',
    ]:
        ensure => 'installed',
    }
}
