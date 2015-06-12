class kde {
    # required by dev-qt/qtwebkit-4.8.5[gstreamer]
    # required by kde-base/kstartupconfig-4.11.9
    # required by kde-base/kdebase-meta-4.13.0
    package_use { 'dev-libs/libxml2':
        use    => '-icu',
        before => Portage::Package['kde-apps/kdebase-meta'],
    }

    portage::package { [
        'kde-apps/kdebase-meta',
        'kde-apps/ksnapshot',
        'kde-apps/gwenview',
        'kde-apps/okular',
        'kde-apps/ark',
        'kde-apps/kmix',
        'kde-apps/ffmpegthumbs',
    ]:
        ensure => installed,
    }

    package_use { 'media-gfx/exiv2':
        use => 'xmp',
    }

    portage::package { 'kde-apps/thumbnailers':
        ensure  => installed,
        require => Package_use['media-gfx/exiv2'],
    }

    class { 'kde::gtk': }

    #
    # The default 'raster' graphics system doesn't sub-pixel render
    # terminal text on transparent backgrounds.  I don't know what this
    # does, but it works.
    #
    eselect { 'qtgraphicssystem':
        set     => 'native',
        require => Portage::Package['kde-apps/kdebase-meta']
    }
}
