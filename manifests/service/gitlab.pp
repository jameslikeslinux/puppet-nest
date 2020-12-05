class nest::service::gitlab (
  String[1] $gmail_password,
) {
  nest::lib::srv { 'gitlab': }

  file { '/srv/gitlab/gitlab.rb':
    mode      => '0600',
    owner     => 'root',
    group     => 'root',
    content   => template('nest/gitlab/gitlab.rb.erb'),
    show_diff => false,
    require   => Nest::Lib::Srv['gitlab'],
    before    => Nest::Lib::Podman_container['gitlab'],
    notify    => Service['container-gitlab'],
  }

  exec { 'podman-network-create-gitlab':
    command => '/usr/bin/podman network create --subnet=10.89.0.0/24 gitlab',
    unless  => '/usr/bin/podman network inspect gitlab',
    require => Class['nest::base::containers'],
  }

  nest::lib::podman_container { 'gitlab':
    image   => 'gitlab/gitlab-ce',
    env     => ["GITLAB_OMNIBUS_CONFIG=from_file('/omnibus_config.rb')"],
    ip      => '10.89.0.2',
    network => 'gitlab',
    volumes => [
      '/srv/gitlab/gitlab.rb:/omnibus_config.rb:ro',
      '/srv/gitlab/config:/etc/gitlab',
      '/srv/gitlab/logs:/var/log/gitlab',
      '/srv/gitlab/data:/var/opt/gitlab',
    ],
    require => Exec['podman-network-create-gitlab'],
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
