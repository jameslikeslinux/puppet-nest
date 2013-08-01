define crypt::device (
    $target,
    $device = $name,
    $keyfile = 'none',
    $order = 99,
) {
    include crypt

    concat::fragment { "crypttab-device-${device}":
        target  => 'crypttab',
        content => template('crypt/crypttab-device.erb'),
        order   => $order,
    }
}
