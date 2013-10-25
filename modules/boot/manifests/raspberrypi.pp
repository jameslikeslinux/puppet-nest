class boot::raspberrypi (
    $kernel,
    $initrd,
    $root,
    $params = [],
) {
    $params_cmdline = join($params, ' ')

    file { '/boot/cmdline.txt':
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => "root=${root} ${params_cmdline}\n",
        require => Class['::raspberrypi'],
    }

    raspberrypi::config { 'kernel':
        value => $kernel,
    }

    raspberrypi::config { 'initramfs':
        value => $initrd,
    }
}
