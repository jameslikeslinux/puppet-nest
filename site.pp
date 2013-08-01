import 'nodes/*.pp'
import 'profiles/**/*.pp'
import 'roles/*.pp'

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
