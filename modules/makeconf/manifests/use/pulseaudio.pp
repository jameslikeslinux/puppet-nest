class makeconf::use::pulseaudio inherits makeconf {
    Makeconf::Use['default'] {
        pulseaudio => true,
    }
}
