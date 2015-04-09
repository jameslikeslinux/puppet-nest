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
        command     => "source /etc/make.conf && /usr/bin/genkernel --kernname='${kernel_name}' --kernel-cc='${compiler}' --makeopts=\"\$MAKEOPTS\" --build-src=/usr/src/linux --kernel-config=/usr/src/linux/config kernel",
        environment => 'HOME=/var/tmp/portage',     # required by distcc
        #creates     => ["/boot/kernel-${kernel_name}-${arch}-${kernel_version}", "/lib/modules/${kernel_version}"],
        timeout     => 0,
        refreshonly => true,
        subscribe   => File['/usr/src/linux/config'],
        require     => Portage::Package['sys-kernel/genkernel'],
        provider    => shell,
    }

    exec { 'module-rebuild':
        command     => '/usr/bin/emerge @module-rebuild',
        environment => 'FEATURES=-getbinpkg',
        timeout     => 0,
        refreshonly => true,
        subscribe   => Exec['genkernel'],
        notify      => Class['kernel::initrd'],
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
