class nest::arch::base {
    $boot_params_deep = [
        $nest::boot_options,

        $nest::numa ? {
            false   => [],
            default => ['numa_balancing=enable'],
        },

        $nest::hugepages ? {
            undef   => [],
            default => ["hugepages=${nest::hugepages}"],
        },

        'elevator=noop',
        'rd.info',
    ]

    $boot_params = flatten($boot_params_deep)
}
