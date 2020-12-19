define nest::lib::repo (
  Optional[String] $url = undef,
  Boolean $default      = false,
  Boolean $unstable     = false,
) {
  # Required for /etc/portage/repos.conf, eix-update
  include 'nest'

  $default_content = $default ? {
    true    => "[DEFAULT]\nmain-repo = ${name}\n\n",
    default => '',
  }

  if $url {
    $repo_content = @("END_REPO")
      [${name}]
      location = /var/db/repos/${name}
      sync-type = git
      sync-uri = $url
      sync-depth = 1
      auto-sync = yes
      | END_REPO

    exec { "/usr/bin/emerge --sync ${name.shellquote}":
      refreshonly => true,
      require     => File["/etc/portage/repos.conf/${name}.conf"],
      notify      => Exec['eix-update'],
    }
  } else {
    $repo_content = @("END_REPO")
      [${name}]
      location = /var/db/repos/${name}
      auto-sync = no
      | END_REPO
  }

  file { "/etc/portage/repos.conf/${name}.conf":
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "${default_content}${repo_content}",
  }

  $accept_keywords_ensure = $unstable ? {
    true    => present,
    default => absent,
  }

  file { "/etc/portage/package.accept_keywords/${name}":
    ensure => $accept_keywords_ensure,
    content => "*/*::${name} ~*\n",
  }
}
