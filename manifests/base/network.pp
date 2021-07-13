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


  if $::nest::wifi {
    package { 'net-wireless/iwd':
      ensure => installed,
    }
    ->
    file { '/var/lib/iwd':
      ensure    => directory,
      mode      => '0600',
      owner     => root,
      group     => root,
      recurse   => true,
      show_diff => false,
      source    => 'puppet:///modules/nest/private/iwd',
    }
    ->  # iwd monitors state directory changes
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
    nest::lib::systemd_reload { 'network':
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
      '/etc/systemd/system/iwd.service.d',
      '/var/lib/iwd',
    ]:
      ensure => absent,
      force  => true,
    }
  }



  #
  # XXX: Remove after NetworkManager is cleaned up
  #
  service { 'NetworkManager':
    ensure => stopped,
    enable => false,
  }
  ->
  package { 'net-misc/networkmanager':
    ensure => absent,
  }
  ->
  file { [
    '/etc/NetworkManager',
    '/var/lib/NetworkManager',
  ]:
    ensure => absent,
    force  => true,
  }
}
