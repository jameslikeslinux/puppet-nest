class dracut {
    portage::package { 'sys-kernel/dracut':
        ensure => installed,
    }
}
