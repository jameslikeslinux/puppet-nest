class kernel (
    $kernel_name     = $kernel::params::kernel_name,
    $kernel_version  = $kernel::params::kernel_version,
    $package_version = $kernel::params::package_version,
    $eselect_name    = $kernel::params::eselect_name,
) inherits kernel::params {
    portage::package { "sys-kernel/${kernel_name}":
        ensure => $package_version,
    }

    kernel::eselect { $eselect_name:
        require => Portage::Package["sys-kernel/${kernel_name}"],
    }
    
    file { '/usr/src/linux/config':
        mode    => 644,
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/kernel/config',
        require => Kernel::Eselect[$eselect_name],
    }

    portage::package { 'sys-kernel/genkernel':
        ensure  => installed,
    }

    exec { 'genkernel':
        command     => "/usr/bin/genkernel --kernname='${kernel_name}' --build-src=/usr/src/linux --kernel-config=/usr/src/linux/config kernel",
        require     => Portage::Package['sys-kernel/genkernel'],
        subscribe   => File['/usr/src/linux/config'],
        notify      => Class['kernel::initrd'],
        creates     => ["/boot/kernel-${kernel_name}-${hardwaremodel}-${kernel_version}", "/lib/modules/${kernel_version}"],
        timeout     => 0,
    }

    class { 'kernel::initrd': 
        kernel_name    => $kernel_name,
        kernel_version => $kernel_version,
    }
}
