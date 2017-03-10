class nest::profile::base::systemd {
  # This exists to ensure other resources that expect to write into this
  # directory come after systemd is installed, which is guaranteed when
  # this class is evaluated because it comes after the portage configuration.
  # Complicated, I know, but it leads to cleaner code overall (without
  # dependencies on the systemd class everywhere).
  file { '/etc/systemd':
    ensure  => directory,
  }

  file { '/etc/hostname':
    content => "${::trusted['certname']}\n",
  }

  file { '/etc/localtime':
    ensure => link,
    target => '/usr/share/zoneinfo/America/New_York',
  }

  # Enable NTP
  service { 'systemd-timesyncd':
    enable => true,
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
    FONT=ter-v${::nest::console_font_size}b
    KEYMAP=${keymap}
    | EOT

  file { '/etc/vconsole.conf':
    content => $vconsole_conf_content,
  }

  file { '/etc/issue':
    content => "\nThis is \\n (\\s \\m \\r) \\t\n\n",
  }

  # Kill all user processes at end of session.
  # This is the default in systemd-230.
  file_line { 'logind.conf-KillUserProcesses':
    path  => '/etc/systemd/logind.conf',
    line  => 'KillUserProcesses=yes',
    match => '^#?KillUserProcesses=',
  }

  # Keep james's systemd services (like tmux) running
  file {
    default:
      owner => 'root',
      group => 'root',
      mode  => '0644',
    ;

    '/var/lib/systemd/linger':
      ensure => directory,
    ;

    '/var/lib/systemd/linger/james':
      ensure => file,
    ;
  }
}
