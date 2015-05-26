class inittab (
    $serial_console,
) {
    file { '/etc/inittab':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('inittab/inittab.erb'),
    }
}
