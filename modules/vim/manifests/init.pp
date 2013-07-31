class vim {
    portage::package { 'app-editors/vim':
        ensure => 'installed',
    }

    eselect { 'vi':
        set     => 'vim',
        require => Portage::Package['app-editors/vim'],
    }
}
