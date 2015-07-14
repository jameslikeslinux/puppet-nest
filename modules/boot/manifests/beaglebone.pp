class boot::beaglebone (
    $kernel,
    $initrd,
    $root = undef,
    $rootfstype = undef,
    $params = [],
) {
    $params_cmdline = join($params, ' ')

    uboot::env { 'bootpart':
        value => '0:1',
    }

    uboot::env { 'bootdir':
        value => '',
    }

    uboot::env { 'bootfile':
        value => $kernel,
    }

    uboot::env { 'fdtdir':
        value => '',
    }

    uboot::env { 'rdfile':
        value => $initrd,
    }

    uboot::env { 'uenvcmd':
        value => 'run loadimage; run loadrd; run loadfdt; run mmcargs; bootz ${loadaddr} ${rdaddr}:${rdsize} ${fdtaddr}',
    }

    uboot::env { 'optargs':
        value => $params_cmdline,
    }

    if $root {
        uboot::env { 'mmcroot':
            value => $root,
        }
    }

    if $rootfstype {
        uboot::env { 'mmcrootfstype':
            value => $rootfstype,
        }
    }
}
