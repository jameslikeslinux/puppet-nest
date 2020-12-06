class nest::service::gitlab (
  String[1] $gmail_password,
) {
  nest::lib::srv { 'gitlab': }
  ->
  file { '/srv/gitlab/gitlab.rb':
    mode      => '0600',
    owner     => 'root',
    group     => 'root',
    content   => template('nest/gitlab/gitlab.rb.erb'),
    show_diff => false,
    notify    => Service['container-gitlab'],
  }
  ->
  nest::lib::container { 'gitlab':
    image   => 'gitlab/gitlab-ce',
    env     => ["GITLAB_OMNIBUS_CONFIG=from_file('/omnibus_config.rb')"],
    publish => ['2222:22', '8080:80', '5050:5050'],
    volumes => [
      '/srv/gitlab/gitlab.rb:/omnibus_config.rb:ro',
      '/srv/gitlab/config:/etc/gitlab',
      '/srv/gitlab/logs:/var/log/gitlab',
      '/srv/gitlab/data:/var/opt/gitlab',
    ],
  }
}
