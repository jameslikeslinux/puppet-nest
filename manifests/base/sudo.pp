class nest::base::sudo {
  package { 'app-admin/sudo':
    ensure  => installed,
    require => Class['nest::base::mta'],
  }
  ->
  file {
    default:
      mode  => '0644',
      owner => 'root',
      group => 'root',
    ;

    '/etc/sudoers.d':
      ensure => directory,
      mode   => '0750',
    ;

    '/etc/sudoers.d/10_env':
      content => "Defaults env_keep += \"SSH_AUTH_SOCK SSH_CLIENT SSH_CONNECTION TMUX TMUX_PANE XAUTHORITY\"\n",
    ;

    '/etc/sudoers.d/10_wheel':
      content => "%wheel ALL=(ALL) NOPASSWD: ALL\n",
    ;
  }
}
