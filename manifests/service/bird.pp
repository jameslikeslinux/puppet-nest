class nest::service::bird {
  package { 'net-misc/bird':
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
      source => 'puppet:///modules/nest/bird/bird.conf',
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
}
