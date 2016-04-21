class nest::profile::workstation::plasma {
  class use {
    package_use { 'kde-plasma/plasma-meta':
      use => 'networkmanager',
    }
  }

  include '::nest::profile::workstation::plasma::use'

  package { 'kde-plasma/plasma-meta':
    ensure => installed,
  }

  $sddm_conf = @("EOT")
    [Theme]
    Current=breeze
    CursorTheme=breeze_cursors

    [XDisplay]
    ServerArguments=-dpi ${::nest::dpi}
    | EOT

  file { '/etc/sddm.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $sddm_conf,
    require => Package['kde-plasma/plasma-meta'],
  }

  service { 'sddm':
    enable  => true,
    require => File['/etc/sddm.conf'],
  }
}
