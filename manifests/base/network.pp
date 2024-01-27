class nest::base::network {
  File {
    mode  => '0644',
    owner => 'root',
    group => 'root',
  }

  file { '/etc/systemd/network':
    ensure       => directory,
    purge        => true,
    recurse      => true,
    force        => true,
    source       => [
      'puppet:///modules/nest/private/network',
      'puppet:///modules/nest/network',
    ],
    sourceselect => all,
    notify       => Exec['systemd-networkd-reload'],
  }

  unless $nest::vpn_client {
    ['20-ethernet', '20-wireless'].each |$network| {
      file {
        "/etc/systemd/network/${network}.network.d":
          ensure => directory;
        "/etc/systemd/network/${network}.network.d/10-domains.conf":
          content => "[Network]\nDomains=nest\n",
          notify  => Exec['systemd-networkd-reload'],
        ;
      }
    }
  }

  exec { 'systemd-networkd-reload':
    command     => '/usr/bin/networkctl reload',
    onlyif      => '/usr/bin/systemctl is-active systemd-networkd',
    unless      => '/usr/bin/systemd-detect-virt -c',
    refreshonly => true,
    before      => Service['systemd-networkd'],
  }

  $wait_for_any_online = @(WAIT)
    [Service]
    ExecStart=
    ExecStart=/lib/systemd/systemd-networkd-wait-online --any
    | WAIT

  file {
    '/etc/systemd/system/systemd-networkd-wait-online.service.d':
      ensure => directory;
    '/etc/systemd/system/systemd-networkd-wait-online.service.d/10-wait-for-any.conf':
      content => $wait_for_any_online,
    ;
  }
  ~>
  nest::lib::systemd_reload { 'network': }
  ~>
  service { 'systemd-networkd':
    enable => true,
  }
}
