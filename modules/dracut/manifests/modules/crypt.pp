class dracut::modules::crypt inherits dracut::modules::default {
    Dracut::Modules['default'] {
        crypt => true,
    }

    Portage::Package['sys-kernel/dracut'] {
        use +> 'device-mapper',
    }

    portage::package { 'sys-fs/lvm2':
        use    => 'udev',
        ensure => installed,
        before => Class['kernel::initrd'],
    }
}
