class nest::service::barrier (
  Boolean $server = true,
) {
  nest::lib::package { 'x11-misc/barrier':
    ensure => installed,
    use    => '-gui',
  }

  if $server {
    firewalld_service { 'synergy':
      ensure => present,
      zone   => 'libvirt',
    }
  }
}
