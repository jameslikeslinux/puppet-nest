class nest::base::wifi {
  if $nest::wifi {
    nest::lib::package { [
      'net-wireless/iw',
      'net-wireless/iwd',
    ]:
      ensure => installed,
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
          require => Nest::Lib::Package['net-wireless/iwd'],
          before  => Service['iwd'],  # iwd monitors state directory changes
        }
      }
    }

    service { 'iwd':
      enable  => true,
      require => Nest::Lib::Package['net-wireless/iwd'],
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

    # For better stability and interactivity
    if $facts['profile']['platform'] =~ /^raspberrypi/ {
      file { '/etc/systemd/system/wifi-power-save-off@.service':
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/nest/wifi/wifi-power-save-off@.service',
      }
      ~>
      nest::lib::systemd_reload { 'wifi': }
      ->
      service { 'wifi-power-save-off@wlan0':
        enable => true,
      }
    }
  } else {
    service { 'iwd':
      ensure => stopped,
      enable => false,
    }
    ->
    nest::lib::package { 'net-wireless/iwd':
      ensure => absent,
    }
    ->
    file { [
      '/etc/systemd/system/iwd.service.d',
      '/var/lib/iwd',
    ]:
      ensure => absent,
      force  => true,
    }
  }
}
