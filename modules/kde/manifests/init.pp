class kde {
    # required by dev-qt/qtwebkit-4.8.5[gstreamer]
    # required by kde-base/kstartupconfig-4.11.9
    # required by kde-base/kdebase-meta-4.13.0
    package_use { 'dev-libs/libxml2':
        use    => '-icu',
        before => Portage::Package['kde-apps/kdebase-meta'],
    }

    # required by kde-frameworks/knotifications-5.13.0[dbus]
    # required by kde-frameworks/kparts-5.13.0
    # required by kde-frameworks/kdelibs4support-5.13.0
    # required by kde-apps/kmix-15.08.0
    # required by @selected
    # required by @world (argument)
    #
    # required by media-libs/phonon-vlc-0.8.2
    #
    # required by media-libs/phonon-4.8.3-r1[vlc]
    # required by kde-frameworks/knotifications-5.13.0
    # required by kde-frameworks/kparts-5.13.0
    # required by kde-frameworks/kdelibs4support-5.13.0
    # required by kde-apps/kmix-15.08.0
    # required by @selected
    # required by @world (argument)
    package_use { [
        'dev-libs/libdbusmenu-qt',
        'media-libs/phonon',
        'media-libs/phonon-vlc',
    ]:
        use    => 'qt5',
        before => Portage::Package['kde-apps/kmix'],
    }

    # required by dev-qt/qtgui-5.4.2-r1
    # required by dev-qt/qtx11extras-5.4.2
    # required by kde-frameworks/kjobwidgets-5.13.0
    # required by kde-frameworks/kio-5.13.0
    # required by kde-frameworks/kinit-5.13.0
    # required by kde-frameworks/kdelibs4support-5.13.0
    # required by kde-apps/kmix-15.08.0
    # required by @selected
    # required by @world (argument)
    package_use { 'x11-libs/libxcb':
        use    => 'xkb',
        before => Portage::Package['kde-apps/kmix'],
    }

    # required by dev-qt/qtcore-5.4.2
    # required by dev-qt/qtx11extras-5.4.2
    # required by kde-frameworks/kjobwidgets-5.13.0
    # required by kde-frameworks/kio-5.13.0
    # required by kde-frameworks/kinit-5.13.0
    # required by kde-frameworks/kdelibs4support-5.13.0
    # required by kde-apps/kmix-15.08.0
    # required by @selected
    # required by @world (argument)
    package_use { 'dev-libs/libpcre':
        use    => 'pcre16',
        before => Portage::Package['kde-apps/kmix'],
    }

    # "kde-apps/kdesu[handbook]" is blocking kde-plasma/kde-cli-tools-5.4.2
    # which is pulled in by kde-apps/kmix-15.08.1:5/5::gentoo
    package_use { 'kde-apps/kdesu':
        use    => '-handbook',
        before => Portage::Package['kde-apps/kmix'],
    }

    # required by kde-plasma/polkit-kde-agent-5.4.0
    # required by kde-base/kdelibs-4.14.10[policykit]
    # required by kde-base/krunner-4.11.22
    # required by kde-base/kdebase-startkde-4.11.22
    # required by kde-apps/kdebase-meta-4.14.3[-minimal]
    # required by @selected
    # required by @world (argument)
    package_use { 'sys-auth/polkit-qt':
        use    => 'qt5',
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
