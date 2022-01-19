class nest::service::gitlab (
  String  $gmail_password,
  Integer $puma_workers = $::nest::concurrency,
) inherits nest {
  nest::lib::srv { 'gitlab': }
  ->
  file {
    default:
      owner => 'root',
      group => 'root',
    ;

    '/srv/gitlab/gitlab.rb':
      mode      => '0600',
      content   => template('nest/gitlab/gitlab.rb.erb'),
      show_diff => false,
      notify    => Service['container-gitlab'],
    ;

    [
      '/srv/gitlab/config',
      '/srv/gitlab/logs',
      '/srv/gitlab/data',
    ]:
      ensure => directory,
    ;
  }
  ->
  nest::lib::container { 'gitlab':
    image   => 'gitlab/gitlab-ce',
    env     => ["GITLAB_OMNIBUS_CONFIG=from_file('/omnibus_config.rb')"],
    publish => ['2222:22', '8000:80', '5050:5050'],
    volumes => [
      '/srv/gitlab/gitlab.rb:/omnibus_config.rb:ro',
      '/srv/gitlab/config:/etc/gitlab',
      '/srv/gitlab/logs:/var/log/gitlab',
      '/srv/gitlab/data:/var/opt/gitlab',
    ],
  }
}
