class nest::base::firmware {
  $files = $::platform ? {
    'pinebookpro' => [
      'brcm/BCM4345C5.hcd',
      'brcm/brcmfmac43456-sdio.bin',
      'brcm/brcmfmac43456-sdio.clm_blob',
      'brcm/brcmfmac43456-sdio.pine64,pinebook-pro.txt',
    ],

    default       => [],
  }

  $dirs = $files.reduce(['/lib/firmware']) |$acc, $file| {
    $subdir = dirname($file)
    $dir = "/lib/firmware/${subdir}"

    if $subdir != '.' and !($dir in $acc) {
      $acc + $dir
    } else {
      $acc
    }
  }

  file { $dirs:
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  $files.each |$file| {
    file { "/lib/firmware/${file}":
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      source => "puppet:///modules/nest/firmware/${file}",
    }
  }
}
