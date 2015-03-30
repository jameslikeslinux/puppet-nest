class qemu (
    $spice = false,
) {
    $use = [
        $spice ? {
            false   => [],
            default => 'spice',
        },
    ]

    portage::package { 'app-emulation/qemu':
        ensure  => installed,
        use     => flatten($use),
    }
}
