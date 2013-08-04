class hostname (
    $hostname,
) {
    file { '/etc/conf.d/hostname':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('hostname/confd.erb'),
    }
}
