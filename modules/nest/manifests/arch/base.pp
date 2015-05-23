class nest::arch::base {
    $boot_params_deep = [
        $nest::boot_options,
        'elevator=noop',
        'rd.info',
    ]

    $boot_params = flatten($boot_params_deep)
}
