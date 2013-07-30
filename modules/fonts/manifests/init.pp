class fonts {
    portage::package { 'media-libs/fontconfig':
        ensure => 'installed',
    }

    define conf {
        file { "/etc/fonts/conf.d/${name}":
            ensure  => 'link',
            target  => "/etc/fonts/conf.avail/${name}",
            require => Portage::Package['media-libs/fontconfig'],
        }
    }

    conf { [
        '10-sub-pixel-rgb.conf',
        '11-lcdfilter-default.conf',
        '70-no-bitmaps.conf',
    ]: }

    portage::package { 'media-fonts/corefonts':
        ensure => 'installed',
    }
}
