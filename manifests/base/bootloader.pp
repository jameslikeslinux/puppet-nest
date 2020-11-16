class nest::base::bootloader {
  # Either due to kernel version or hardware implementation,
  # z3fold hangs on Pinebook Pro
  $zswap_zpool = $::platform ? {
    'pinebookpro' => 'zbud',
    default       => 'z3fold',
  }

  $kernel_cmdline = [
    'init=/lib/systemd/systemd',
    'quiet',
    'loglevel=3',
    'fbcon=scrollback:1024k',

    $::nest::isolcpus ? {
      undef   => [],
      default => [
        "isolcpus=${::nest::isolcpus}",
        "nohz_full=${::nest::isolcpus}",
        "rcu_nocbs=${::nest::isolcpus}",
      ],
    },

    # Let kernel swap to compressed memory instead of a physical volume, which
    # is slow and, currently, prone to hanging.  max_pool_percent=100 ensures
    # the OOM killer is invoked before zswap sends pages to physical swap.
    # Physical swap is still useful for hibernation.
    #
    # See: https://github.com/openzfs/zfs/issues/7734
    'zswap.enabled=1',
    'zswap.compressor=lzo-rle',
    "zswap.zpool=${zswap_zpool}",
    'zswap.max_pool_percent=100',
    'vm.swappiness=100',

    $::nest::kernel_cmdline_hiera,
  ].flatten.join(' ').strip

  case $::nest::bootloader {
    systemd: {
      contain 'nest::base::bootloader::systemd'
    }

    default: {
      contain 'nest::base::bootloader::grub'

      exec { 'dracut':
        command     => 'version=$(ls /lib/modules | sort -V | tail -1) && dracut --force --kver $version',
        refreshonly => true,
        timeout     => 0,
        provider    => shell,
        notify      => Class['nest::base::bootloader::grub'],
      }
    }
  }
}
