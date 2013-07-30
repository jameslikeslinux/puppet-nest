class makeconf::use::networkmanager inherits makeconf {
    Makeconf::Use['default'] {
        networkmanager => true,
    }
}
