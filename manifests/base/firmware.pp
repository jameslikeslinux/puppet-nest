class nest::base::firmware {
  case $facts['profile']['platform'] {
    'beagleboneblack': {
      contain '::nest::base::firmware::uboot'

      file { '/boot/am335x-boneblack.dtb':
        source => '/usr/src/linux/arch/arm/boot/dts/am335x-boneblack.dtb',
      }
    }

    'pinebookpro': {
      contain '::nest::base::firmware::arm'
      contain '::nest::base::firmware::uboot'

      Class['nest::base::firmware::arm']
      ~> Class['nest::base::firmware::uboot']

      file {
        '/boot/rockchip':
          ensure => directory,
        ;

        '/boot/rockchip/rk3399-pinebook-pro.dtb':
          source => '/usr/src/linux/arch/arm64/boot/dts/rockchip/rk3399-pinebook-pro.dtb',
        ;
      }
    }

    'raspberrypi': {
      contain '::nest::base::firmware::raspberrypi'
      contain '::nest::base::firmware::uboot'

      Class['nest::base::firmware::uboot']
      -> Class['nest::base::firmware::raspberrypi']

      file {
        '/boot/bcm2711-rpi-400.dtb':
          source => '/usr/src/linux/arch/arm64/boot/dts/broadcom/bcm2711-rpi-400.dtb',
        ;

        '/boot/overlays':
          source  => '/usr/src/linux/arch/arm64/boot/dts/overlays',
          links   => follow,
          recurse => true,
          purge   => true,
          force   => true,
          ignore  => ['.*', '*.dts', 'Makefile'],
        ;
      }
    }
  }

  package { 'sys-kernel/linux-firmware':
    ensure => installed,
  }

  $files = {
    'manjaro/brcm/BCM4345C5.hcd'                   => ['pinebookpro'],
    'plugable/brcm/BCM20702A1-0a5c-21e8.hcd'       => ['haswell'],
    'raspberrypi/brcm/BCM4345C5.hcd'               => ['raspberrypi'],
    'raspberrypi/brcm/brcmfmac43456-sdio.bin'      => ['pinebookpro', 'raspberrypi'],
    'raspberrypi/brcm/brcmfmac43456-sdio.clm_blob' => ['pinebookpro', 'raspberrypi'],
    'raspberrypi/brcm/brcmfmac43456-sdio.txt'      => ['pinebookpro', 'raspberrypi'],
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
