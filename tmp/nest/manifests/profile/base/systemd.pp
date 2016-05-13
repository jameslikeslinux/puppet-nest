class nest::profile::base::systemd {
  nest::portage::package_use { 'sys-apps/systemd':
    use => 'cryptsetup',
  }

  file { '/etc/hostname':
    content => "${::trusted['certname']}\n",
  }

  file { '/etc/localtime':
    ensure => link,
    target => '/usr/share/zoneinfo/America/New_York',
  }

  augeas { 'nsswitch-hosts-add-myhostname':
    context => '/files/etc/nsswitch.conf',
    changes => "set database[. = 'hosts']/service[last()+1] myhostname",
    onlyif  => "get database[. = 'hosts']/service[last()] != 'myhostname'",
  }

  file_line { 'locale.gen-en_US.UTF-8':
    path  => '/etc/locale.gen',
    line  => 'en_US.UTF-8 UTF-8',
    match => '^#en_US.UTF-8 UTF-8$',
  }

  exec { '/usr/sbin/locale-gen':
    refreshonly => true,
    subscribe   => File_line['locale.gen-en_US.UTF-8'],
  }

  file { '/etc/locale.conf':
    content => "LANG=en_US.utf8\n",
    require => Exec['/usr/sbin/locale-gen'],
  }

  package { 'media-fonts/terminus-font':
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

  $keymap = $::nest::dvorak ? {
    true    => 'dvorak-nocaps',
    default => 'us-nocaps',
  }

  $vconsole_conf_content = @("EOT")
    FONT=ter-v${::nest::console_font_size_nearest}b
    KEYMAP=${keymap}
    | EOT

  file { '/etc/vconsole.conf':
    content => $vconsole_conf_content,
  }

  file { '/etc/issue':
    content => "\nThis is \\n (\\s \\m \\r) \\t\n\n",
  }
}
