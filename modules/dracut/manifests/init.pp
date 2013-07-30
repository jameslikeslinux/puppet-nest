class dracut {
    dracut::modules { 'default': }

    portage::package { 'sys-kernel/dracut':
        ensure  => 'installed',
    }
}
