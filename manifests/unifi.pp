class nest::unifi {
  include '::nest'
  include '::nest::docker'

  nest::srv { 'unifi': }

  file {
    default:
      ensure => directory,
      owner  => 'ubnt',
      group  => 'ubnt',
    ;

    '/srv/unifi':
      mode    => '0750',
      require => Nest::Srv['unifi'],
    ;

    [
      '/srv/unifi/config',
      '/srv/unifi/config/data',
    ]:
      mode => '0755',
    ;

    '/srv/unifi/config/data/system.properties':
      ensure => file,
      mode   => '0644',
    ;
  }

  file_line {
    default:
      require => File['/srv/unifi/config/data/system.properties'],
      notify  => Docker::Run['unifi'],
      path    => '/srv/unifi/config/data/system.properties',
    ;

    'unifi.http.port':
      line  => 'unifi.http.port=80',
      match => '^unifi\.http\.port=',
    ;

    'unifi.https.port':
      line  => 'unifi.https.port=443',
      match => '^unifi\.https\.port=',
    ;
  }

  docker_network { 'mgmt':
    ensure  => present,
    driver  => 'macvlan',
    subnet  => '172.22.2.0/24',
    gateway => '172.22.2.1',
    options => "parent=enp5s0.2",
  }

  $cpuset = $::nest::availcpus_expanded.join(',')

  docker::run { 'unifi':
    image            => 'linuxserver/unifi',
    net              => 'mgmt',
    env              => ['PUID=1002', 'PGID=1002'],
    volumes          => ['/srv/unifi/config:/config'],
    extra_parameters => [
      "--cpuset-cpus=${cpuset}",
      '--ip=172.22.2.2',
      '--sysctl net.ipv4.ip_unprivileged_port_start=0'
    ],
    service_provider => 'systemd',
    require          => [
      Docker_network['mgmt'],
      File['/srv/unifi/config'],
    ],
  }
}
