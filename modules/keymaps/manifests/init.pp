class keymaps (
    $keymap = 'us',
) {
    file { '/etc/conf.d/keymaps':
        mode    => 644,
        owner   => 'root',
        group   => 'root',
        content => template('keymaps/keymaps.erb'),
        notify  => [Openrc::Service['keymaps'], Class['kernel::initrd']],
    }

    openrc::service { 'keymaps': }
}
