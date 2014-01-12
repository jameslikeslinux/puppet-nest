class kernel::modules::blacklist {
    file { '/etc/modprobe.d/blacklist.conf':
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/kernel/blacklist.conf',
    }
}
