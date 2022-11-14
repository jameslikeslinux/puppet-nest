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
  ~>
  exec { 'systemd-networkd-reload':
    command     => '/bin/networkctl reload',
    onlyif      => '/bin/systemctl is-active systemd-networkd',
    refreshonly => true,
  }
  ->
  service { 'systemd-networkd':
    enable => true,
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

  if $nest::wifi {
    package { 'net-wireless/iwd':
      ensure => installed,
    }

    # Workaround reassociation instability on Raspberry Pi
    $iwd_main_conf_content = @(IWD_MAIN_CONF)
      [General]
      ControlPortOverNL80211=false
      | IWD_MAIN_CONF
    $iwd_main_conf_ensure = $facts['profile']['platform'] ? {
      'raspberrypi' => present,
      default       => absent,
    }
    file {
      default:
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        require => Package['net-wireless/iwd'],
      ;

      '/etc/iwd':
        ensure => directory,
      ;

      '/etc/iwd/main.conf':
        ensure  => $iwd_main_conf_ensure,
        content => $iwd_main_conf_content,
        notify  => Service['iwd'],
      ;
    }

    if $nest::wlans {
      $nest::wlans.unwrap.each |$wlan, $wlan_params| {
        $wlan_params_sensitive = $wlan_params.reduce({}) |$memo, $param| {
          if $param[0] == 'passphrase' {
            $memo + { $param[0] => Sensitive($param[1]) }
          } else {
            $memo + { $param[0] => $param[1] }
          }
        }

        nest::lib::wlan { $wlan:
          *       => $wlan_params_sensitive,
          require => Package['net-wireless/iwd'],
          before  => Service['iwd'],  # iwd monitors state directory changes
        }
      }
    }

    service { 'iwd':
      enable => true,
    }

    $iwd_service_fix_content = @(IWD_SERVICE_FIX)
      [Unit]
      After=dbus.service
      | IWD_SERVICE_FIX

    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root',
      ;

      '/etc/systemd/system/iwd.service.d':
        ensure => directory,
      ;

      '/etc/systemd/system/iwd.service.d/10-fix-shutdown.conf':
        content => $iwd_service_fix_content,
      ;
    }
    ~>
    nest::lib::systemd_reload { 'iwd':
      notify => Service['iwd'],
    }
  } else {
    service { 'iwd':
      ensure => stopped,
      enable => false,
    }
    ->
    package { 'net-wireless/iwd':
      ensure => absent,
    }
    ->
    file { [
      '/etc/iwd',
      '/etc/systemd/system/iwd.service.d',
      '/var/lib/iwd',
    ]:
      ensure => absent,
      force  => true,
    }
  }
}
