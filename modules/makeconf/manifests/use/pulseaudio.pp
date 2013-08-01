class makeconf::use::pulseaudio inherits makeconf::use::default {
    Makeconf::Use['default'] {
        pulseaudio => true,
    }
}
