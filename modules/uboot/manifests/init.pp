class uboot {
    concat { '/boot/uEnv.txt': }

    concat::fragment { 'uEnv.txt-header':
        target => '/boot/uEnv.txt',
        source => 'puppet:///modules/uboot/uEnv.txt-header',
        order  => '00',
    }
}
