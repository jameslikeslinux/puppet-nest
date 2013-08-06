class kde {
    $mixin = "funtoo/1.0/linux-gnu/mix-ins/kde"
    exec { "eselect-profile-mixin-kde":
        command => "/usr/bin/eselect profile add '${mixin}'",
        unless  => "/usr/bin/eselect profile show | /bin/grep '${mixin}'",
        notify  => Class['portage'],
    }

    portage::package { [
        'kde-base/kdebase-meta',
        'kde-base/ksnapshot',
        'kde-base/gwenview',
        'kde-base/okular',
        'kde-base/ark',
        'kde-base/kmix',
        'kde-base/ffmpegthumbs',
        'kde-base/thumbnailers',
    ]:
        ensure => installed,
    }

    class { 'xdm':
        displaymanager => 'kdm',
        require        => Portage::Package['kde-base/kdebase-meta'],
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
