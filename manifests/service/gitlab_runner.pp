class nest::service::gitlab_runner (
  Integer             $concurrent = $nest::concurrency,
  Optional[String]    $dns        = undef,
  Nest::ServiceEnsure $ensure     = running,
  Hash[String, Hash]  $instances  = {},
) inherits nest {
  $install = [Nest::Lib::Srv['gitlab-runner'], File['/usr/local/bin/gitlab-runner']]
  $service = Nest::Lib::Container['gitlab-runner']

  if $ensure == absent {
    $runner_ensure  = absent
    $runner_require = $service
    $runner_before  = $install
  } else {
    $runner_ensure  = present
    $runner_require = $install
    $runner_before  = $service

    file_line { 'gitlab-runner-concurrent':
      path    => '/srv/gitlab-runner/config.toml',
      line    => "concurrent = ${concurrent}",
      match   => '^concurrent =',
      require => Nest::Lib::Container['gitlab-runner'], # no restart required
    }
  }

  nest::lib::srv { 'gitlab-runner':
    ensure => $runner_ensure,
    ignore => ['config.toml', '.runner_system_id'],
    purge  => true,
    notify => Exec['gitlab-runner-unregister-all'], # unregister purged instances
  }

  file { '/usr/local/bin/gitlab-runner':
    ensure => $runner_ensure,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/scripts/gitlab-runner.sh',
  }

  $instances.each |$instance, $attributes| {
    nest::lib::gitlab_runner { "${trusted['certname']}-${instance}":
      require => $runner_require,
      before  => $runner_before,
      *       => {
        dns => $dns,
      } + $attributes + {
        ensure => $runner_ensure,
      },
    }
  }

  nest::lib::container { 'gitlab-runner':
    ensure  => $ensure,
    image   => 'gitlab/gitlab-runner',
    dns     => $dns,
    volumes => [
      '/srv/gitlab-runner:/etc/gitlab-runner',
      '/run/podman/podman.sock:/var/run/docker.sock',
    ],
  }
}
