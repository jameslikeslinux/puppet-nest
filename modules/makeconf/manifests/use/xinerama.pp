class makeconf::use::xinerama inherits makeconf {
    Makeconf::Use['default'] {
        xinerama => true,
    }
}
