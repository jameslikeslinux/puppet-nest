class synergy (
    $qt4 = false,
) {
    $use = $qt4 ? {
        true    => undef,
        default => '-qt4',
    }

    portage::package { 'x11-misc/synergy':
        ensure => installed,
        use    => $use,
    }
}
