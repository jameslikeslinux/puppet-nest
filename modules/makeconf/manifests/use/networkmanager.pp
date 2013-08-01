class makeconf::use::networkmanager inherits makeconf::use::default {
    Makeconf::Use['default'] {
        networkmanager => true,
    }
}
