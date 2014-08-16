define uboot::env (
    $value,
) {
    include uboot

    concat::fragment { "uEnv.txt-${name}":
        target  => '/boot/uEnv.txt',
        content => template('uboot/env.erb'),
    }    
}
