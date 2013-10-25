define raspberrypi::config (
    $value,
) {
    include raspberrypi

    concat::fragment { "raspberrypi-config-${name}":
        target  => '/boot/config.txt',
        content => $name ? {
            'initramfs' => "initramfs ${value}\n",
            default     => "${name}=${value}\n",
        },
    }
}
