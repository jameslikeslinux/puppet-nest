define dracut::conf (
    $ensure = present,
    $boot_devices = undef,
    $force_drivers = undef,
    $kernel_cmdline = undef,
) {
    file { "/etc/dracut.conf.d/${name}.conf":
        ensure  => $ensure,
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('dracut/conf.erb'),
        require => Class['dracut'],
        notify  => Class['kernel::initrd'],
    }
}
