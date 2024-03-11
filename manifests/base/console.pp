class nest::base::console {
  $keymap = $nest::dvorak ? {
    true    => 'dvorak-nocaps',
    default => 'us-nocaps',
  }

  nest::lib::package { 'media-fonts/terminus-font':
    ensure => installed,
  }

  file {
    default:
      mode  => '0644',
      owner => 'root',
      group => 'root';

    '/usr/share/keymaps/i386/dvorak/dvorak-nocaps.map.gz':
      source => 'puppet:///modules/nest/keymaps/dvorak-nocaps.map.gz';

    '/usr/share/keymaps/i386/qwerty/us-nocaps.map.gz':
      source => 'puppet:///modules/nest/keymaps/us-nocaps.map.gz';
  }

  $vconsole_conf_content = @("EOT")
    FONT=ter-v${nest::console_font_size}b
    KEYMAP=${keymap}
    | EOT

  file { '/etc/vconsole.conf':
    content => $vconsole_conf_content,
  }

  # Update initramfs for all changes in this class
  Class['nest::base::console']
  ~> Class['nest::base::dracut']
}
