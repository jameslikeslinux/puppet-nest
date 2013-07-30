define dracut::conf (
    $boot_devices,
) {
    include dracut

    file { "/etc/dracut.conf.d/${name}.conf":
        mode    => 644,
        owner   => 'root',
        group   => 'root',
        content => template('dracut/conf.erb'),
        require => Class['dracut'],
        notify  => Class['kernel::initrd'],
    }
}
