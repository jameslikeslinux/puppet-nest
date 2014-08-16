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

    uboot::env { 'rdfile':
        value => $initrd,
    }

    uboot::env { 'loadramdisk':
        value => 'load mmc ${bootpart} ${rdaddr} ${bootdir}/${rdfile}',
    }

    uboot::env { 'uenvcmd':
        value => 'run loaduimage; run loadramdisk; run loadfdt; run mmcargs; bootm ${kloadaddr} ${rdaddr} ${fdtaddr}',
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
