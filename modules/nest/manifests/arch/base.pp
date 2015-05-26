class nest::arch::base {
    $boot_params_deep = [
        $nest::boot_options,

        $nest::serial_console ? {
            undef   => [],
            default => ["console=ttyS${nest::serial_console},115200n8", 'console=tty0'],
        },

        'elevator=noop',
        'rd.info',
    ]

    $boot_params = flatten($boot_params_deep)
}
