define dracut::conf (
    $boot_devices,
) {
    file { "/etc/dracut.conf.d/${name}.conf":
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('dracut/conf.erb'),
        require => Class['dracut'],
        notify  => Class['kernel::initrd'],
    }
}
