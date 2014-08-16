class kernel (
    $kernel_name,
    $kernel_version,
    $package_name = $kernel_name,
    $package_version,
    $eselect_name,
    $config_source,
    $cryptsetup = true,
    $distcc,
) {
    $arch = $hardwaremodel ? {
        /arm.*/ => 'arm',
        default => $hardwaremodel,
    }

    if $distcc {
        $compiler = '/usr/lib/distcc/bin/gcc'
        Class['distcc::client'] -> Exec['genkernel']
    } else {
        $compiler = '/usr/bin/gcc'
    }

    portage::package { "sys-kernel/${package_name}":
        ensure => $package_version,
    }

    kernel::eselect { $eselect_name:
        require => Portage::Package["sys-kernel/${package_name}"],
    }

    file { '/usr/src/linux/config':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => $config_source,
        require => Kernel::Eselect[$eselect_name],
    }

    portage::package { 'sys-kernel/genkernel':
        ensure  => installed,
        use     => $cryptsetup ? {
            false   => '-cryptsetup',
            default => undef,
        }
    }

    exec { 'genkernel':
        command     => "/usr/bin/genkernel --kernname='${kernel_name}' --kernel-cc='${compiler}' --build-src=/usr/src/linux --kernel-config=/usr/src/linux/config kernel",
        subscribe   => File['/usr/src/linux/config'],
        notify      => Class['kernel::initrd'],
        creates     => ["/boot/kernel-${kernel_name}-${arch}-${kernel_version}", "/lib/modules/${kernel_version}"],
        timeout     => 0,
        require     => Portage::Package['sys-kernel/genkernel'],
        environment => "HOME=/var/tmp/portage",     # required by distcc
    }

    class { 'kernel::initrd':
        kernel_name    => $kernel_name,
        kernel_version => $kernel_version,
    }

    concat { '/etc/conf.d/modules': }

    kernel::modules { 'default':
        source => 'puppet:///modules/kernel/modules.confd',
        order  => '00',
    }

    concat { '/etc/modprobe.d/blacklist.conf':
        notify => Class['kernel::initrd'],
    }

    concat::fragment { 'blacklist.conf-header':
        target => '/etc/modprobe.d/blacklist.conf',
        source => 'puppet:///modules/kernel/blacklist.conf',
        order => '00',
    }
}
