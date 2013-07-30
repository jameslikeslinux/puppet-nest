class dracut::modules::plymouth inherits dracut {
    Dracut::Modules['default'] {
        plymouth => true,
    }
}
