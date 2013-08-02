class vcs {
    portage::package { 'dev-vcs/subversion':
        use => ['perl', '-dso'],
    }

    portage::package { 'dev-vcs/git':
        use     => 'subversion',
        require => Portage::Package['dev-vcs/subversion'],
    }
}
