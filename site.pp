import 'nodes/*.pp'

if $osfamily == 'Gentoo' {
    # XXX: Package installation depends on Portage configuration
    class { 'portage': }

    Package {
        require => Class['portage'],
    }

    Portage::Package {
        require => Class['portage'],
    }
}
