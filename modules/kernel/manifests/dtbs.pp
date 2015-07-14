class kernel::dtbs (
    $fdtfile,
) {
    exec { 'make-dtbs':
        command     => '/usr/bin/make -C /usr/src/linux dtbs',
        refreshonly => true,
        subscribe   => Class['kernel'],
    }

    file { "/boot/${fdtfile}":
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => "/usr/src/linux/arch/${kernel::arch}/boot/dts/${fdtfile}",
        require => Exec['make-dtbs'],
    }
}
