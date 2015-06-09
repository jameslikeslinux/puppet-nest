class qemu (
    $spice = false,
    $numa  = false,
) {
    $use = [
        $spice ? {
            false   => [],
            default => 'spice',
        },

        $numa ? {
            false   => [],
            default => 'numa',
        },
    ]

    portage::package { 'app-emulation/qemu':
        ensure  => installed,
        use     => flatten($use),
    }
}
