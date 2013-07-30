class makeconf::use::zsh_completion inherits makeconf {
    Makeconf::Use['default'] {
        zsh_completion => true,
    }
}
