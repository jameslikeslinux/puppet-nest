define crypt::device (
    $target,
    $device   = $name,
    $keyfile  = 'none',
    $order    = 99,
    $bootdisk = true,
    $options  = [],
) {
    include crypt

    if $bootdisk {
        fail('Use profile variable boot_decrypt.')
    } else {
        include crypt::service

        concat::fragment { "dmcrypt-device-${device}":
            target  => '/etc/conf.d/dmcrypt',
            content => template('crypt/dmcrypt-device.erb'),
            order   => $order,
        }
    }
}
