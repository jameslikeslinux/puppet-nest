# GitLab-only subnet canary. Enrollment state is runtime-owned, never Hiera data.
class nest::host::kestrel::tailscale {
  tag('luna_gitlab')

  # Keep global --noop effective: the build helper explicitly overrides it.
  package_accept_keywords { 'net-vpn/tailscale':
    accept_keywords => '~riscv',
    before          => Package['net-vpn/tailscale'],
  }

  package { 'net-vpn/tailscale':
    ensure => '1.102.2',
  }

  # An independent early guard prevents trusted source zones or a later
  # firewalld/Tailscale change from widening decrypted tailscale0 traffic.
  file { '/etc/nest/luna-gitlab.nft':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/nest/tailscale/luna-gitlab.nft',
    notify => Service['luna-gitlab-guard'],
  }

  systemd::manage_unit { 'luna-gitlab-guard.service':
    unit_entry    => {
      'Description' => 'Confine Luna subnet traffic before shared firewall rules',
      'Before'      => 'tailscaled.service',
    },
    service_entry => {
      'Type'            => 'oneshot',
      'RemainAfterExit' => true,
      'ExecStart'       => '/usr/sbin/nft -f /etc/nest/luna-gitlab.nft',
      'ExecReload'      => '/usr/sbin/nft -f /etc/nest/luna-gitlab.nft',
    },
    install_entry => { 'WantedBy' => 'multi-user.target' },
  }

  service { 'luna-gitlab-guard':
    ensure  => running,
    enable  => true,
    require => [File['/etc/nest/luna-gitlab.nft'], Systemd::Manage_unit['luna-gitlab-guard.service']],
  }

  firewalld_zone { 'luna':
    interfaces       => ['tailscale0'],
    target           => 'DROP',
    purge_rich_rules => true,
    purge_services   => true,
    purge_ports      => true,
  }

  file { '/etc/firewalld/policies/luna-gitlab.xml':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/nest/tailscale/luna-gitlab.xml',
    require => Firewalld_zone['luna'],
    notify  => Class['firewalld::reload'],
  }

  file { '/etc/systemd/system/tailscaled.service.d':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
  -> file { '/etc/systemd/system/tailscaled.service.d/nest.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "[Unit]\nRequires=luna-gitlab-guard.service firewalld.service\nAfter=luna-gitlab-guard.service firewalld.service\n",
    notify  => Nest::Lib::Systemd_reload['luna-gitlab'],
  }

  nest::lib::systemd_reload { 'luna-gitlab':
    before => Service['tailscaled'],
  }

  service { 'tailscaled':
    ensure  => running,
    enable  => true,
    require => [Package['net-vpn/tailscale'], Service['luna-gitlab-guard'], Class['firewalld::reload']],
  }

  file { '/usr/local/sbin/nest-tailscale-config':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/nest/tailscale/nest-tailscale-config.py',
  }

  # Set only reviewed preferences; never log in, enroll, accept DNS/routes,
  # enable SSH/exit-node service, or persist credentials through Puppet.
  exec { 'luna-gitlab-tailscale-preferences':
    command => '/usr/local/sbin/nest-tailscale-config',
    unless  => '/usr/local/sbin/nest-tailscale-config --check',
    require => [Service['tailscaled'], File['/usr/local/sbin/nest-tailscale-config']],
  }
}
