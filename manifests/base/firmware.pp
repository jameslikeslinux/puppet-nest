class nest::base::firmware {
  if $nest::dtb_file {
    $soc_vendor = dirname($nest::dtb_file)

    $dtb_root = $facts['profile']['architecture'] ? {
      'arm'   => '/boot',
      default => "/boot/${soc_vendor}",
    }

    file {
      $dtb_root:
        ensure => directory;
      "${dtb_root}/${basename($nest::dtb_file)}":
        source => "/usr/src/linux/arch/${facts['profile']['architecture']}/boot/dts/${nest::dtb_file}",
      ;
    }

    case $soc_vendor {
      'amlogic': {
        contain 'nest::base::firmware::uboot'
        # contain 'nest::base::firmware::arm'
        # contain 'nest::base::firmware::uboot'

        # Class['nest::base::firmware::arm']
        # ~> Class['nest::base::firmware::uboot']
      }

      'allwinner': {
        contain 'nest::base::firmware::arm'
        contain 'nest::base::firmware::uboot'

        Class['nest::base::firmware::arm']
        ~> Class['nest::base::firmware::uboot']

        if $facts['profile']['platform'] == 'pine64' {
          file { '/lib/firmware/rtl_bt/rtl8723bs_config.bin':
            ensure  => link,
            target  => 'rtl8723bs_config-OBDA8723.bin',
            require => Package['sys-kernel/linux-firmware'],
          }
        }
      }

      'broadcom': {
        contain 'nest::base::firmware::uboot'

        if $facts['profile']['platform'] =~ /^raspberrypi/ {
          contain 'nest::base::firmware::raspberrypi'

          Class['nest::base::firmware::uboot']
          -> Class['nest::base::firmware::raspberrypi']

          file { '/boot/overlays':
            source  => '/usr/src/linux/arch/arm64/boot/dts/overlays',
            links   => follow,
            recurse => true,
            purge   => true,
            force   => true,
            ignore  => ['.*', '*.dts', 'Makefile'],
          }
        }
      }

      'rockchip': {
        contain 'nest::base::firmware::arm'

        if $facts['profile']['platform'] == 'rock5' {
          contain 'nest::base::firmware::rockchip'

          Class['nest::base::firmware::rockchip']
          ~> Class['nest::base::firmware::uboot']
        } else {
          contain 'nest::base::firmware::uboot'

          Class['nest::base::firmware::arm']
          ~> Class['nest::base::firmware::uboot']
        }
      }

      'ti/omap': {
        contain 'nest::base::firmware::uboot'
      }
    }
  }

  package { 'sys-kernel/linux-firmware':
    ensure => installed,
  }

  $files = {
    'linux/brcm/brcmfmac43455-sdio.bin'                       => ['raspberrypi3', 'rockpro64'],
    'linux/brcm/brcmfmac43455-sdio.clm_blob'                  => ['raspberrypi3', 'rockpro64'],
    'linux/brcm/brcmfmac43455-sdio.pine64,rockpro64-v2.1.txt' => ['rockpro64'],
    'manjaro/brcm/BCM4345C5.hcd'                              => ['pinebookpro'],
    'plugable/brcm/BCM20702A1-0a5c-21e8.hcd'                  => ['haswell'],
    'raspberrypi/brcm/BCM4345C0.hcd'                          => ['raspberrypi3', 'rockpro64'],
    'raspberrypi/brcm/BCM4345C5.hcd'                          => ['raspberrypi4'],
    'raspberrypi/brcm/brcmfmac43456-sdio.bin'                 => ['pinebookpro', 'raspberrypi4'],
    'raspberrypi/brcm/brcmfmac43456-sdio.clm_blob'            => ['pinebookpro', 'raspberrypi4'],
    'raspberrypi/brcm/brcmfmac43456-sdio.txt'                 => ['pinebookpro', 'raspberrypi4'],
  }

  $files_categorized = $files.reduce([{}, {}]) |$memo, $file| {
    $present   = $memo[0]
    $absent    = $memo[1]
    $source    = $file[0]
    $platforms = $file[1]
    $target    = regsubst($file[0], '^[^/]*/', '')

    if $facts['profile']['platform'] in $platforms {
      [$present + { $target => $source }, $absent]
    } else {
      [$present, $absent + { $target => $source }]
    }
  }

  $files_present = $files_categorized[0]
  $files_absent  = $files_categorized[1] - $files_categorized[0]

  $files_present.each |$target, $source| {
    file { "/lib/firmware/${target}":
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      source  => "puppet:///modules/nest/firmware/${source}",

      # Makes the directory structure
      require => Package['sys-kernel/linux-firmware'],
    }
  }

  $files_absent.each |$target, $source| {
    file { "/lib/firmware/${target}":
      ensure => absent,
    }
  }
}
