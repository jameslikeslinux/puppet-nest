class dracut::modules::plymouth inherits dracut::modules::default {
    Dracut::Modules['default'] {
        plymouth => true,
    }
}
