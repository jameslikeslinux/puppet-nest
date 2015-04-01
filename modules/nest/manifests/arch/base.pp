class nest::arch::base {
    $boot_params_deep = [
        $nest::boot_options,
        'elevator=noop',
        'rd.info',

        $nest::boot_decrypt ? {
            undef   => [],
            default => ['rd.luks.key=keyfile.img:LABEL=boot'],
        },

        $nest::boot_decrypt ? {
            undef   => [],
            default => prefix($nest::boot_decrypt, 'rd.luks.uuid=')
        },
    ]

    $boot_params = flatten($boot_params_deep)
}
