class nest::lib::repos {
  tag 'profile'

  file {
    default:
      ensure  => directory,
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      purge   => true,
      recurse => true,
      force   => true,
    ;

    '/etc/portage/repos.conf':
      # use defaults
    ;

    '/var/db/repos':
      recurselimit => 1,
    ;
  }

  # Don't let eix-sync override my tmux window title
  file { '/etc/eixrc/10-nostatusline':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "NOSTATUSLINE=true\n",
  }

  exec { 'eix-update':
    command     => '/usr/bin/eix-update',
    refreshonly => true,
    timeout     => 0,
  }

  # eix depends on repository configurations and
  # repository changes should update eix
  Nest::Lib::Repo <||>
  ~> Exec['eix-update']
}
