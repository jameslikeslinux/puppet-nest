class nest::base::network {
  file { '/etc/systemd/network':
    ensure       => directory,
    mode         => '0644',
    owner        => root,
    group        => root,
    purge        => true,
    recurse      => true,
    force        => true,
    source       => [
      'puppet:///modules/nest/private/network',
      'puppet:///modules/nest/network',
    ],
    sourceselect => all,
  }
  ->
  service { 'systemd-networkd':
    enable => true,
  }

  unless $facts['is_container'] {
    exec { 'systemd-networkd-reload':
      command     => '/bin/networkctl reload',
      onlyif      => '/bin/systemctl is-active systemd-networkd',
      refreshonly => true,
      subscribe   => File['/etc/systemd/network'],
      before      => Service['systemd-networkd'],
    }
  }

  $wait_for_any_online = @(WAIT)
    [Service]
    ExecStart=
    ExecStart=/lib/systemd/systemd-networkd-wait-online --any
    | WAIT

  file {
    default:
      mode  => '0644',
      owner => 'root',
      group => 'root',
    ;

    '/etc/systemd/system/systemd-networkd-wait-online.service.d':
      ensure => directory,
    ;

    '/etc/systemd/system/systemd-networkd-wait-online.service.d/10-wait-for-any.conf':
      content => $wait_for_any_online,
    ;
  }
  ~>
  nest::lib::systemd_reload { 'network': }
}
