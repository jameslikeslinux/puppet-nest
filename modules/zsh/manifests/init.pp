class zsh {
    portage::package { 'app-shells/zsh':
        ensure => installed,
    }
}
