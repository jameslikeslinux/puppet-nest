class zsh::fake {
    # This is to work around that the shell must exist
    # to be set for a user such as root, but the root user
    # resource must be successful in order to install packages
    exec { '/bin/ln -s /bin/bash /bin/zsh':
        creates => '/bin/zsh',
    }
}
