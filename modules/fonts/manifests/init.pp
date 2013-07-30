class fonts {
    portage::package { 'media-libs/fontconfig':
        ensure => installed,
    }

    define conf (
        $ensure = present,
    ) {
        file { "/etc/fonts/conf.d/${name}":
            ensure  => $ensure ? {
                present => link,
                default => absent,
            },
            target  => "/etc/fonts/conf.avail/${name}",
            require => Portage::Package['media-libs/fontconfig'],
        }
    }

    conf { [
        '10-sub-pixel-rgb.conf',
        '11-lcdfilter-default.conf',
        '70-no-bitmaps.conf',
    ]: }

    #
    # Make sure nobody (I'm looking at you KDE) messes up my beautiful
    # font configuration
    #
    conf { '50-user.conf':
        ensure => absent,
    }

    portage::package { [
        'media-fonts/corefonts',
        'media-fonts/liberation-fonts',
    ]:
        ensure => installed,
    }

    #
    # Make Liberation fonts the default for
    # sans-serif, serif, and monospace
    #
    file { '/etc/fonts/local.conf':
        mode   => 644,
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/fonts/local.conf',
        require => [
            Portage::Package['media-libs/fontconfig'],
            Portage::Package['media-fonts/liberation-fonts'],
        ]
    }
}
