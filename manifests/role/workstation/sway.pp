class nest::role::workstation::sway {
  nest::lib::portage::package_use { 'gui-wm/sway':
    use => ['-swaybar', '-swaylock', '-swayidle'],
  }

  package { [
    'gui-wm/sway',
    'gui-apps/waybar',
  ]:
    ensure => installed,
  }

  exec { 'move-sway-binary':
    command => '/bin/mv -f /usr/bin/sway /usr/bin/sway.real',
    unless  => '/bin/grep \'^#!/bin/bash$\' /usr/bin/sway',
    require => Package['gui-wm/sway'],
  }

  # Sway will scale the display to our gui_scaling_factor, but we need
  # to change the DPI to effect our text_scaling_factor
  $gui_scaling_factor  = $::nest::gui_scaling_factor
  $text_scaling_factor = $::nest::text_scaling_factor
  $qt_font_dpi         =   0 + inline_template('<%= ((@text_scaling_factor / @gui_scaling_factor) * 96.0).round %>')
  $gdk_dpi_scale       = 0.0 + inline_template('<%= (@text_scaling_factor / @gui_scaling_factor).round(3) %>')

  $sway_wrapper_content = @("END_WRAPPER")
    #!/bin/bash
    GDK_DPI_SCALE=${gdk_dpi_scale} QT_FONT_DPI=${qt_font_dpi} exec /usr/bin/sway.real "$@"
    | END_WRAPPER

  file { '/usr/bin/sway':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $sway_wrapper_content,
    require => Exec['move-sway-binary'],
  }
}
