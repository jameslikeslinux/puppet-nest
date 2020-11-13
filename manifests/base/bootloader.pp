class nest::base::bootloader {
  $kernel_cmdline = [
    'init=/lib/systemd/systemd',
    'quiet',
    'loglevel=3',
    'fbcon=scrollback:1024k',

    # Allow up to 3/4 of memory to be compressed with a fast algorithm
    'zswap.enabled=1',
    'zswap.compressor=lzo-rle',
    'zswap.zpool=z3fold',
    'zswap.max_pool_percent=75',

    # Tune virtual memory for zswap: initiate swapping more opportunistically
    # and swap more per kswapd event (1% of memory vs 0.1% default)
    'vm.swappiness=100',
    'vm.watermark_scale_factor=100',

    $::nest::isolcpus ? {
      undef   => [],
      default => [
        "isolcpus=${::nest::isolcpus}",
        "nohz_full=${::nest::isolcpus}",
        "rcu_nocbs=${::nest::isolcpus}",
      ],
    },
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
