import 'roles/*.pp'
import 'nodes/*.pp'

if $osfamily == 'Gentoo' {
    # XXX: Package installation depends on Portage configuration
    class { 'portage': }
    Portage::Package {
        require => Class['portage'],
    }
}
