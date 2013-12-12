class erlang (
    $graphical = false,
) {
    $use = [
        'hipe',
        'kpoll',
        'smp',
        $graphical ? {
            false => [],
            default => ['tk', 'wxwidgets'],
        },
    ]

    portage::package { 'dev-lang/erlang':
        use => flatten($use),
    }
}
