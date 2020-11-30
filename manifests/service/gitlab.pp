class nest::service::gitlab {
  include 'nest::service::docker'

  nest::lib::srv { 'gitlab': }

  $gitlab_omnibus_config = @(GITLAB_OMNIBUS_CONFIG)
    external_url 'https://gitlab.james.tl'

    # For proxied SSL
    # See: https://docs.gitlab.com/omnibus/settings/nginx.html#supporting-proxied-ssl
    nginx['listen_port'] = 80
    nginx['listen_https'] = false

    # Use dark theme by default
    gitlab_rails['gitlab_default_theme'] = 11
    | GITLAB_OMNIBUS_CONFIG

  file { '/srv/gitlab/gitlab.rb':
    mode    => '0600',
    owner   => 'root',
    group   => 'root',
    content => $gitlab_omnibus_config,
    require => Nest::Lib::Srv['gitlab'],
    notify  => Docker::Run['gitlab'],
  }

  docker_network { 'gitlab':
    ensure           => present,
    subnet           => ['172.18.0.0/24', 'fc00:18::/64'],
    additional_flags => '--ipv6',
  }

  docker::run { 'gitlab':
    image            => 'gitlab/gitlab-ce',
    net              => 'gitlab',
    extra_parameters => [
      '--ip 172.18.0.2',
      '--ip6 fc00:18::2',
    ],
    env              => ["GITLAB_OMNIBUS_CONFIG=from_file('/omnibus_config.rb')"],
    volumes          => [
      '/srv/gitlab/gitlab.rb:/omnibus_config.rb:ro',
      '/srv/gitlab/config:/etc/gitlab',
      '/srv/gitlab/logs:/var/log/gitlab',
      '/srv/gitlab/data:/var/opt/gitlab',
    ],
    service_provider => 'systemd',
    require          => Docker_network['gitlab'],
  }

  # Docker's IPv6 support expects public addresses
  # so it doesn't set up a NAT automatically
  firewall { '100 gitlab nat':
    table    => nat,
    chain    => 'POSTROUTING',
    source   => 'fc00:18::/64',
    jump     => 'MASQUERADE',
    provider => ip6tables,
  }

  # Use iptables to forward the SSH service to avoid listener conflicts
  # with Docker's own port exposure method, and to support IPv6
  nest::lib::port_forward { 'gitlab ssh':
    port            => 22,
    proto           => tcp,
    source_ip4      => '104.156.227.40',
    destination_ip4 => '172.18.0.2',
    source_ip6      => '2001:19f0:300:2005::40',
    destination_ip6 => 'fc00:18::2',
  }

  nest::lib::revproxy { 'gitlab.james.tl':
    destination => '172.18.0.2',
    ip          => ['104.156.227.40', '2001:19f0:300:2005::40'],
    websockets  => '.*\.ws',
  }
}
