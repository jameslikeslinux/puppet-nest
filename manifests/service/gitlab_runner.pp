class nest::service::gitlab_runner (
  String              $registration_token,
  Integer             $concurrent = $nest::concurrency,
  Optional[String]    $dns        = undef,
  Nest::ServiceEnsure $ensure     = running,
  Hash[String, Hash]  $instances  = {},
) inherits nest {
  unless $facts['is_container'] {
    if $ensure == absent {
      $runner_ensure  = absent
      $runner_require = Nest::Lib::Container['gitlab-runner']
      $runner_before  = Nest::Lib::Srv['gitlab-runner']
    } else {
      $runner_ensure  = present
      $runner_require = Nest::Lib::Srv['gitlab-runner']
      $runner_before  = Nest::Lib::Container['gitlab-runner']

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
    }

    $instances.each |$instance, $attributes| {
      nest::lib::gitlab_runner { "${trusted['certname']}-${instance}":
        require => $runner_require,
        before  => $runner_before,
        *       => {
          dns                => $dns,
          registration_token => $registration_token,
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
}
