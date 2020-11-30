class nest::service::gitlab (
  String[1] $gmail_password,
) {
  include 'nest::service::docker'

  nest::lib::srv { 'gitlab': }

  $gitlab_omnibus_config = @("GITLAB_OMNIBUS_CONFIG")
    external_url 'https://gitlab.james.tl'

    # For proxied SSL
    # See: https://docs.gitlab.com/omnibus/settings/nginx.html#supporting-proxied-ssl
    nginx['listen_port'] = 80
    nginx['listen_https'] = false

    # Use dark theme by default
    gitlab_rails['gitlab_default_theme'] = 2

    # Gmail outbound
    # See: https://docs.gitlab.com/omnibus/settings/smtp.html#gmail
    gitlab_rails['smtp_enable'] = true
    gitlab_rails['smtp_address'] = 'smtp.gmail.com'
    gitlab_rails['smtp_port'] = 587
    gitlab_rails['smtp_user_name'] = 'gitlab@james.tl'
    gitlab_rails['smtp_password'] = '${gmail_password}'
    gitlab_rails['smtp_domain'] = 'smtp.gmail.com'
    gitlab_rails['smtp_authentication'] = 'login'
    gitlab_rails['smtp_enable_starttls_auto'] = true
    gitlab_rails['smtp_tls'] = false
    gitlab_rails['smtp_openssl_verify_mode'] = 'peer'

    # Gmail inbound
    # See: https://docs.gitlab.com/ee/administration/incoming_email.html#gmail
    gitlab_rails['incoming_email_enabled'] = true
    gitlab_rails['incoming_email_address'] = 'gitlab+%{key}@james.tl'
    gitlab_rails['incoming_email_email'] = 'gitlab@james.tl'
    gitlab_rails['incoming_email_password'] = '${gmail_password}'
    gitlab_rails['incoming_email_host'] = 'imap.gmail.com'
    gitlab_rails['incoming_email_port'] = 993
    gitlab_rails['incoming_email_ssl'] = true
    gitlab_rails['incoming_email_start_tls'] = false
    gitlab_rails['incoming_email_mailbox_name'] = 'inbox'
    gitlab_rails['incoming_email_idle_timeout'] = 60
    gitlab_rails['incoming_email_expunge_deleted'] = true

    # Let projects opt-in to DevOps features
    gitlab_rails['gitlab_default_projects_features_issues'] = false
    gitlab_rails['gitlab_default_projects_features_merge_requests'] = false
    gitlab_rails['gitlab_default_projects_features_wiki'] = false
    gitlab_rails['gitlab_default_projects_features_snippets'] = false
    gitlab_rails['gitlab_default_projects_features_builds'] = false
    gitlab_rails['gitlab_default_projects_features_container_registry'] = false
    | GITLAB_OMNIBUS_CONFIG

  file { '/srv/gitlab/gitlab.rb':
    mode      => '0600',
    owner     => 'root',
    group     => 'root',
    content   => $gitlab_omnibus_config,
    show_diff => false,
    require   => Nest::Lib::Srv['gitlab'],
    notify    => Docker::Run['gitlab'],
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
