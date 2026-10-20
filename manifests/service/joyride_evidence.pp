# Operator-only infrastructure custody and immutable-runtime admission. There is
# no daemon, timer, application/CI invocation or production consumer activation.
class nest::service::joyride_evidence {
  # Select the dedicated encrypted scope only while this class is compiling.
  # Credentials are deliberately looked up in the body, after scope selection.
  $scope = 'evidence-supervisor'
  $key = assert_type(Sensitive[String], lookup('nest::joyride::evidence::signing_key_base64'))
  $public = assert_type(String, lookup('nest::joyride::evidence::public_key'))
  $registry = assert_type(Sensitive[String], lookup('nest::joyride::evidence::registry_dockerconfig'))
  $token = assert_type(Sensitive[String], lookup('nest::joyride::evidence::gitlab_read_token'))

  if $public != '34ddf287aeeb91f9a1c96181f0f07cbd4c37311762e8b8fe5f58ccb76d3a0a2b' {
    fail('Joyride evidence root differs from the independently admitted generation')
  }

  file { ['/opt/joyride-evidence-supervisor', '/etc/joyride-evidence']:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  ['evidence_supervisor.py', 'evidence_identity.py'].each |$script| {
    file { "/opt/joyride-evidence-supervisor/${script}":
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      source  => "puppet:///modules/nest/app/joyride/${script}",
      require => File['/opt/joyride-evidence-supervisor'],
    }
  }

  $config = {
    'schema'      => 1,
    'image'       => 'registry.gitlab.joyfullee.me/joy/joyride/joyride-evidence@sha256:3b3b3da4de283e91ec0aca5af1f89f43a55305b4ee2f960d3da50a29960ed535',
    'source_head' => 'b500350d181db4a64f5f89357b8335901907fe6f',
    'public_key'  => $public,
  }

  file { '/etc/joyride-evidence/config.json':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => to_json($config),
    require => File['/etc/joyride-evidence'],
  }

  file { ['/var/lib/joyride-evidence', '/var/lib/joyride-evidence/sessions']:
    ensure => directory,
    owner  => $nest::user,
    group  => $nest::user,
    mode   => '0700',
  }
  File['/var/lib/joyride-evidence'] -> File['/var/lib/joyride-evidence/sessions']

  $secrets = {
    'signing-key.base64' => $key,
    'registry.json'     => $registry,
    'gitlab-token'      => $token,
  }
  $secrets.each |$name, $value| {
    file { "/var/lib/joyride-evidence/${name}":
      ensure    => file,
      owner     => $nest::user,
      group     => $nest::user,
      mode      => '0600',
      content   => $value,
      show_diff => false,
      backup    => false,
      require   => File['/var/lib/joyride-evidence'],
    }
  }
}
