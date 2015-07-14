class vcs {
    portage::package { 'dev-vcs/subversion':
        use => ['perl', '-dso'],
    }

    portage::package { 'dev-vcs/git':
        # Bug when linking against libgit.a with USE=subversion
        # See: https://bugs.gentoo.org/show_bug.cgi?id=529914
        # and: https://bugs.gentoo.org/show_bug.cgi?id=466178
        use     => $architecture ? {
            /arm/   => undef,
            default => 'subversion',
        },
        require => Portage::Package['dev-vcs/subversion'],
    }
}
