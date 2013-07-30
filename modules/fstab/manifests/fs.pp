define fstab::fs (
    $device = $name,
    $mountpoint,
    $type,
    $options = 'defaults',
    $dump = 0,
    $pass = 0,
    $ensure = 'present',
) {
    include fstab

    concat::fragment { "fstab-${device}":
        target  => 'fstab',
        content => template('fstab/fs.erb'),
        ensure  => $ensure,
    }
}
