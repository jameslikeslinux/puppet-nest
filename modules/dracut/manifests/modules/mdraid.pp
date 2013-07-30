class dracut::modules::mdraid inherits dracut {
    Dracut::Modules['default'] {
        mdraid => true,
    }
}
