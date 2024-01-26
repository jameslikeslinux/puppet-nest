class nest::base::bootloader {
  # For nest::base::console::keymap
  include 'nest::base::console'

  $kernel_cmdline = [
    'loglevel=3', # must come after 'quiet', if specified

    $facts['zpools_cached'] ? {
      true    => [],
      default => 'zfs_force',
    },

    # Let I/O preferences be configurable at boot time
    "rd.vconsole.font=ter-v${nest::console_font_size}b",
    "rd.vconsole.keymap=${nest::base::console::keymap}",

    $nest::wifi ? {
      true    => 'cfg80211.ieee80211_regdom=US',
      default => [],
    },

    $nest::isolate_smt ? {
      true    => "nohz_full=${facts['processors']['count'] / 2}-${facts['processors']['count'] - 1}",
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

    # For iotop
    'delayacct',

    $nest::kernel_cmdline,

    'init=/lib/systemd/systemd',
  ].flatten.join(' ').strip

  case $nest::bootloader {
    'systemd': {
      contain 'nest::base::bootloader::systemd'
    }

    default: {
      contain 'nest::base::bootloader::grub'
    }
  }
}
