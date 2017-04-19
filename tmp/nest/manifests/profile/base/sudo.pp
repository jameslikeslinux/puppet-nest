class nest::profile::base::sudo {
  package { 'app-admin/sudo':
    ensure => installed,
  }

  file { '/etc/sudoers.d/10_env':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "Defaults env_keep += \"SSH_AUTH_SOCK SSH_CLIENT TMUX TMUX_PANE XAUTHORITY\"\n",
    require => Package['app-admin/sudo'],
  }

  file { '/etc/sudoers.d/10_wheel':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => "%wheel ALL=(ALL) NOPASSWD: ALL\n",
    require => Package['app-admin/sudo'],
  }
}
