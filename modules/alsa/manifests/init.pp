class alsa (
    $default_card = undef,
) {
    $ensure = $default_card ? {
        undef   => absent,
        default => present,
    }

    file { '/etc/asound.conf':
        ensure  => $ensure,
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('alsa/asound.conf.erb'),
    }
}
