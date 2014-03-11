import 'nodes/*.pp'

if $osfamily == 'Gentoo' {
    # XXX: Package installation depends on Portage configuration
    class { 'portage':
        eselect_ensure => installed,
    }

    Package {
        require => Class['portage'],
    }

    Portage::Package {
        require => Class['portage'],
    }
}
