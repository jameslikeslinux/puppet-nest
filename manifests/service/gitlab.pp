class nest::service::gitlab (
  String[1] $gmail_password,
) {
  include 'nest'

  if $::nest::containers == 'docker' {

  nest::lib::srv { 'gitlab': }

  file { '/srv/gitlab/gitlab.rb':
    mode      => '0600',
    owner     => 'root',
    group     => 'root',
    content   => template('nest/gitlab/gitlab.rb.erb'),
    show_diff => false,
    require   => Nest::Lib::Srv['gitlab'],
    notify    => Docker::Run['gitlab'],
  }

  docker_network { 'gitlab':
    ensure           => present,
    subnet           => ['10.89.0.0/24'],
  }

  docker::run { 'gitlab':
    image            => 'gitlab/gitlab-ce',
    net              => 'gitlab',
    env              => ["GITLAB_OMNIBUS_CONFIG=from_file('/omnibus_config.rb')"],
    extra_parameters => [
      '--ip=10.89.0.2',
    ],
    volumes          => [
      '/srv/gitlab/gitlab.rb:/omnibus_config.rb:ro',
      '/srv/gitlab/config:/etc/gitlab',
      '/srv/gitlab/logs:/var/log/gitlab',
      '/srv/gitlab/data:/var/opt/gitlab',
    ],
    service_provider => 'systemd',
    require          => Docker_network['gitlab'],
  }

  # Use iptables to forward the SSH service to avoid listener
  # conflicts with the container's own port publishing method
  nest::lib::port_forward { 'gitlab ssh':
    port            => 22,
    proto           => tcp,
    source_ip4      => '104.156.227.40',
    destination_ip4 => '10.89.0.2',
  }

  nest::lib::reverse_proxy {
    default:
      ip => ['104.156.227.40', '2001:19f0:300:2005::40'],
    ;

    'gitlab.james.tl':
      destination     => '10.89.0.2',
      encoded_slashes => true,
      websockets      => true,
    ;

    'registry.gitlab.james.tl':
      destination => '10.89.0.2:5050',
    ;
  }

  }
}
