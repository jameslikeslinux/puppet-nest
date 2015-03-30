class profile::base::arch::base {
    $boot_params_deep = [
        $profile::base::boot_options,
        'elevator=noop',
        'rd.info',

        $profile::base::boot_decrypt ? {
            undef   => [],
            default => ['rd.luks.key=keyfile.img:LABEL=boot'],
        },

        $profile::base::boot_decrypt ? {
            undef   => [],
            default => prefix($profile::base::boot_decrypt, 'rd.luks.uuid=')
        },
    ]

    $boot_params = flatten($boot_params_deep)
}
