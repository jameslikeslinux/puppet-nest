class inittab (
    $serial_console,
) {
    if $serial_console {
        augeas { 'enable-serial-console-login':
            context => '/files/etc/inittab',
            changes => [
                "set s${serial_console}/runlevels 12345",
                "set s${serial_console}/action respawn",
                "set s${serial_console}/process \"/sbin/agetty -L 115200 ttyS${serial_console} vt100\"",
            ],
        }
    }
}
