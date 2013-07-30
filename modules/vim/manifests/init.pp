class vim {
    portage::package { 'app-editors/vim':
        ensure => 'installed',
    }

    eselect { 'vi':
        set => 'vim',
    }
}
