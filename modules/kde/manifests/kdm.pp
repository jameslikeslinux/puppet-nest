class kde::kdm (
    $keymap      = 'us',
    $xkbvariant  = undef,
    $xkboptions  = [],
    $dpi         = undef,
) {
    class { 'xdm':
        displaymanager => 'kdm',
        require        => Portage::Package['kde-base/kdebase-meta'],
    }

    file { '/usr/share/config/kdm/Xsetup':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => template('kde/kdm-xsetup.erb'),
        require => Portage::Package['kde-base/kdebase-meta'],
    }
}
