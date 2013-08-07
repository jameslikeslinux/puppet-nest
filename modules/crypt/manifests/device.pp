define crypt::device (
    $target,
    $device   = $name,
    $keyfile  = 'none',
    $order    = 99,
    $bootdisk = true,
) {
    include crypt

    if $bootdisk {
        concat::fragment { "crypttab-device-${device}":
            target  => 'crypttab',
            content => template('crypt/crypttab-device.erb'),
            order   => $order,
        }
    } else {
        include crypt::service

        concat::fragment { "dmcrypt-device-${device}":
            target  => '/etc/conf.d/dmcrypt',
            content => template('crypt/crypttab-device.erb'),
            order   => $order,
        }
    }
}
