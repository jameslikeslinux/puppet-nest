class kde::kdm (
    $keymap      = 'us',
    $xkbvariant  = undef,
    $xkboptions  = [],
    $dpi         = undef,
    $synergy     = undef,
) {
    class { 'xdm':
        displaymanager => 'kdm',
        require        => Portage::Package['kde-apps/kdebase-meta'],
    }

    file { '/usr/share/config/kdm/Xsetup':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => template('kde/kdm-xsetup.erb'),
        require => Portage::Package['kde-apps/kdebase-meta'],
    }

    file { '/usr/share/config/kdm/Xstartup':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => template('kde/kdm-xstartup.erb'),
        require => Portage::Package['kde-apps/kdebase-meta'],
    }
}
