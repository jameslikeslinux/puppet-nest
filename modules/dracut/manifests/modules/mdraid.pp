class dracut::modules::mdraid inherits dracut::modules::default {
    Dracut::Modules['default'] {
        mdraid => true,
    }
}
