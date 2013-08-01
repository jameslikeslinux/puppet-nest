class makeconf::use::zsh_completion inherits makeconf::use::default {
    Makeconf::Use['default'] {
        zsh_completion => true,
    }
}
