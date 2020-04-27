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
  $dpi       =   0 + inline_template('<%= ((@text_scaling_factor / @gui_scaling_factor) * 96.0).round %>')
  $dpi_scale = 0.0 + inline_template('<%= (@text_scaling_factor / @gui_scaling_factor).round(3) %>')

  $sway_wrapper_content = @("END_WRAPPER")
    #!/bin/bash
    GDK_DPI_SCALE=${dpi_scale} QT_FONT_DPI=${dpi} exec /usr/bin/sway.real "$@"
    | END_WRAPPER

  file { '/usr/bin/sway':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $sway_wrapper_content,
    require => Exec['move-sway-binary'],
  }

  $xresources_content = @("XRESOURCES")
    Xft.dpi: $dpi
    | XRESOURCES

  file { '/etc/sway/Xresources':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $xresources_content,
    require => Package['gui-wm/sway'],
  }

  $xkb_variant = $::nest::dvorak ? {
    true    => "input type:keyboard xkb_variant dvorak\n",
    default => '',
  }

  $xkb_options = $::nest::swap_alt_win ? {
    true    => "input type:keyboard xkb_options ctrl:nocaps,altwin:swap_alt_win\n",
    default => "input type:keyboard xkb_options ctrl:nocaps\n",
  }

  $input_conf = "input type:keyboard xkb_layout us\n${xkb_variant}${xkb_options}"

  $output_conf = @("OUTPUT_CONF")
    output * scale $::nest::gui_scaling_factor
    output * subpixel rgb
    | OUTPUT_CONF

  file {
    default:
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
    ;

    '/etc/sway/config.d':
      ensure => directory,
      require => Package['gui-wm/sway'],
    ;

    '/etc/sway/config.d/10-cursor':
      content => "seat seat0 xcursor_theme breeze_cursors 24\n",
    ;

    '/etc/sway/config.d/10-input':
      content => $input_conf,
    ;

    '/etc/sway/config.d/10-output':
      content => $output_conf,
    ;

    '/etc/sway/config.d/10-xwayland':
      content => "exec_always xrdb -merge /etc/sway/Xresources\n",
    ;
  }
}
