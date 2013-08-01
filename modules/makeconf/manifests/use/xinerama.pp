class makeconf::use::xinerama inherits makeconf::use::default {
    Makeconf::Use['default'] {
        xinerama => true,
    }
}
