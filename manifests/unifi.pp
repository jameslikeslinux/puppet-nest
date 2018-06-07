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
      '/srv/unifi/data',
    ]:
      mode => '0755',
    ;

    '/srv/unifi/data/system.properties':
      ensure => file,
      mode   => '0644',
    ;
  }

  file_line {
    default:
      require => File['/srv/unifi/data/system.properties'],
      notify  => Docker::Run['unifi'],
      path    => '/srv/unifi/data/system.properties',
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
    options => "parent=bond0.1002",
  }

  $cpuset = $::nest::availcpus_expanded.join(',')

  docker::run { 'unifi':
    image            => 'jacobalberty/unifi',
    net              => 'mgmt',
    dns              => '172.22.2.1',
    env              => [
      'RUNAS_UID0=false',
      'UNIFI_UID=1002',
      'UNIFI_GID=1002',
      'TZ=America/New_York',
    ],
    volumes          => ['/srv/unifi:/unifi'],
    extra_parameters => [
      "--cpuset-cpus=${cpuset}",
      '--ip=172.22.2.2',
    ],
    service_provider => 'systemd',
    require          => [
      Docker_network['mgmt'],
      File['/srv/unifi'],
    ],
  }
}
