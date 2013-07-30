class zsh {
    portage::package { 'app-shells/zsh':
        ensure => 'installed',
    }

    class { 'makeconf::use::zsh_completion': }
}
