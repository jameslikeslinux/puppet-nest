define crypt::device (
    $target,
    $uuid,
    $device   = $name,
    $keyfile  = 'none',
    $order    = 99,
    $bootdisk = true,
    $options  = [],
) {
    include crypt

    if $bootdisk {
        dracut::conf { $target:
            boot_devices   => $device,
            kernel_cmdline => "rd.luks.uuid=${uuid}",
        }

        concat::fragment { "crypttab-device-${device}":
            target  => 'crypttab',
            content => template('crypt/crypttab-device.erb'),
            order   => "${order}-${target}",
        }
    } else {
        include crypt::service

        concat::fragment { "dmcrypt-device-${device}":
            target  => '/etc/conf.d/dmcrypt',
            content => template('crypt/dmcrypt-device.erb'),
            order   => $order,
        }
    }
}
