class nest::base::bootloader {
  $kernel_cmdline = [
    'init=/lib/systemd/systemd',
    'loglevel=3',
    'quiet',

    $::nest::isolate_smt ? {
      true    => "nohz_full=${facts['processorcount'] / 2}-${facts['processorcount'] - 1}",
      default => [],
    },

    # Let kernel swap to compressed memory instead of a physical volume, which
    # is slow and, currently, prone to hanging.  max_pool_percent=100 ensures
    # the OOM killer is invoked before zswap sends pages to physical swap.
    # Physical swap is still useful for hibernation.
    #
    # See: https://github.com/openzfs/zfs/issues/7734
    # See also: nest::base::zfs for workarounds
    'vm.swappiness=100',
    'zswap.enabled=1',
    'zswap.compressor=lzo-rle',
    'zswap.zpool=z3fold',
    'zswap.max_pool_percent=100',

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
