# Project-scoped execution only. The manager token stays outside the rootless
# engine identity; jobs can control that engine, never the host rootful engine.
class nest::service::joyride_ci {
  unless $facts['is_container'] {
    # Account creation precedes the base class's final subuid/subgid files, so
    # order individual engine dependencies rather than requiring that class.
    include nest::base::containers
    require nest::tool::qemu

    $scope = 'ci-runner'
    # lookup_options may already be cached before this body selects its scope.
    # Wrap the decrypted lookup explicitly as well as accepting converted data.
    $looked_up_token = lookup('nest::service::joyride_ci::runner_token')
    $runner_token = $looked_up_token ? {
      Sensitive[String] => $looked_up_token,
      default           => Sensitive(assert_type(String, $looked_up_token)),
    }

    if !('joyride-ci' in $nest::rootless_users) {
      fail('Joyride CI requires a dedicated subordinate identity in nest::rootless_users')
    }

    group { 'joyride-ci':
      ensure => present,
      system => true,
    }
    ->
    user { 'joyride-ci':
      ensure     => present,
      system     => true,
      gid        => 'joyride-ci',
      groups     => [],
      membership => inclusive,
      home       => '/var/lib/joyride-ci',
      shell      => '/sbin/nologin',
      password   => '!',
      managehome => false,
    }
    -> File['/etc/subuid', '/etc/subgid']

    file { ['/var/lib/joyride-ci', '/var/lib/joyride-ci/tmp']:
      ensure  => directory,
      owner   => 'joyride-ci',
      group   => 'joyride-ci',
      mode    => '0700',
      require => User['joyride-ci'],
    }
    File['/var/lib/joyride-ci'] -> File['/var/lib/joyride-ci/tmp']

    file { '/etc/systemd/system/joyride-ci-engine.service':
      ensure => file,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => 'puppet:///modules/nest/app/joyride/joyride-ci-engine.service',
      notify => Nest::Lib::Systemd_reload['joyride-ci'],
    }
    ~>
    nest::lib::systemd_reload { 'joyride-ci': }
    ~>
    service { 'joyride-ci-engine':
      ensure  => running,
      enable  => true,
      require => [File['/etc/subuid', '/etc/subgid'], File['/var/lib/joyride-ci/tmp']],
    }

    file { '/etc/joyride-ci':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0700',
    }
    ->
    file { '/etc/joyride-ci/config.toml':
      ensure    => file,
      owner     => 'root',
      group     => 'root',
      mode      => '0600',
      content   => Sensitive(epp('nest/app/joyride/ci-runner.toml.epp', {
        'runner_token' => $runner_token.unwrap,
        'qemu_targets' => $nest::tool::qemu::user_targets,
      })),
      show_diff => false,
      backup    => false,
      notify    => Service['container-joyride-ci-manager'],
    }

    nest::lib::container { 'joyride-ci-manager':
      image   => 'gitlab/gitlab-runner:alpine-v19.3.2',
      volumes => [
        '/etc/ssl/certs/ca-certificates.crt:/etc/ssl/certs/ca-certificates.crt:ro',
        '/etc/joyride-ci:/etc/gitlab-runner',
        '/run/joyride-ci:/run/joyride-ci',
      ],
      require => [File['/etc/joyride-ci/config.toml'], Service['joyride-ci-engine']],
    }

    file { '/etc/systemd/system/container-joyride-ci-manager.service.d':
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }
    ->
    file { '/etc/systemd/system/container-joyride-ci-manager.service.d/10-engine.conf':
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "[Unit]\nRequires=joyride-ci-engine.service\nAfter=joyride-ci-engine.service\nPartOf=joyride-ci-engine.service\n",
      notify  => Nest::Lib::Systemd_reload['joyride-ci'],
    }
  }
}
