class nest::base::bird {
  if $nest::bird_role {
    $router_name = $facts['fqdn'] # lint:ignore:legacy_facts
    $router_id   = $nest::host_records[$router_name]

    # This class owns this config for now
    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root';
      '/etc/iproute2':
        ensure => directory;
      '/etc/iproute2/rt_tables':
        content => "100 bird\n",
      ;
    }

    nest::lib::package { 'net-misc/bird':
      ensure => installed,
    }
    ->
    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root',
      ;

      '/etc/bird.conf':
        content => epp('nest/bird/bird.conf.epp', { 'mode' => $nest::bird_role, 'router_id' => $router_id }),
      ;

      '/etc/systemd/system/bird.service':
        source => 'puppet:///modules/nest/bird/bird.service',
      ;
    }
    ~>
    nest::lib::systemd_reload { 'bird': }
    ~>
    service { 'bird':
      enable => true,
    }
  } else {
    service { 'bird':
      ensure => stopped,
      enable => false,
    }
    ->
    file { [
      '/etc/bird.conf',
      '/etc/systemd/system/bird.service',
    ]:
      ensure => absent,
    }
    ->
    nest::lib::package { 'net-misc/bird':
      ensure => absent,
    }

    file { '/etc/iproute2':
      ensure => absent,
      force  => true,
    }
  }
}
