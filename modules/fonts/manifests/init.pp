class fonts (
    $lcd = true,
) {
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
    ]:
        ensure => $lcd ? {
            false   => absent,
            default => present,
        }
    }

    conf { '70-no-bitmaps.conf': }

    #
    # Make sure nobody (I'm looking at you KDE) messes up my beautiful
    # font configuration
    #
    conf { '50-user.conf':
        ensure => absent,
    }

    portage::package { 'media-fonts/corefonts':
        ensure => installed,
        use    => 'tahoma',
    }

    portage::package { [
        'media-fonts/liberation-fonts',
        'media-fonts/dejavu',
    ]:
        ensure => installed,
    }

    #
    # Install international fonts, and others recommended by
    # the chrome ebuild.  Not that I can read these languages,
    # but it does make international websites look better.
    #
    portage::package { [
        'media-fonts/arphicfonts',
        'media-fonts/bitstream-cyberbit',
        'media-fonts/droid',
        'media-fonts/ja-ipafonts',
        'media-fonts/takao-fonts',
        'media-fonts/wqy-microhei',
        'media-fonts/wqy-zenhei',
    ]:
        ensure => installed,
    }

    #
    # Make Liberation fonts the default for
    # sans-serif and serif; DejaVu for monospace
    #
    file { '/etc/fonts/local.conf':
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/fonts/local.conf',
        require => [
            Portage::Package['media-libs/fontconfig'],
            Portage::Package['media-fonts/liberation-fonts'],
            Portage::Package['media-fonts/dejavu'],
        ]
    }
}
