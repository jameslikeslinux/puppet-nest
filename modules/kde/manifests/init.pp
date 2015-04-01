class kde {
    # required by dev-qt/qtwebkit-4.8.5[gstreamer]
    # required by kde-base/kstartupconfig-4.11.9
    # required by kde-base/kdebase-meta-4.13.0
    package_use { 'dev-libs/libxml2':
        use    => '-icu',
        before => Portage::Package['kde-base/kdebase-meta'],
    }

    portage::package { [
        'kde-base/kdebase-meta',
        'kde-base/ksnapshot',
        'kde-base/gwenview',
        'kde-base/okular',
        'kde-base/ark',
        'kde-base/kmix',
        'kde-base/ffmpegthumbs',
    ]:
        ensure => installed,
    }

    package_use { 'media-gfx/exiv2':
        use => 'xmp',
    }

    portage::package { 'kde-base/thumbnailers':
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
        require => Portage::Package['kde-base/kdebase-meta']
    }
}
