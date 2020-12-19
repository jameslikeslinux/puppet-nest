class nest::base::portage {
  class { 'portage':
    eselect_ensure => installed,
  }



  #
  # make.conf
  #
  $makejobs_memory = ceiling($facts['memory']['system']['total_bytes'] / (512.0 * 1024 * 1024))
  $makejobs_distcc = $::nest::distcc_hosts.reduce($::nest::processorcount) |$memo, $host| { $memo + $host[1] }
  $makejobs        = min($makejobs_memory, $makejobs_distcc)
  $loadlimit       = $::nest::processorcount + 1

  # Prioritize makeopts passed in from CI by facter
  $makeopts = pick($facts['makeopts'], "-j${makejobs} -l${loadlimit}")

  $emerge_default_opts_ensure = $facts['emerge_default_opts'] ? {
    undef   => absent,
    default => present,
  }

  portage::makeconf {
    'features':
      content => ['distcc'],
    ;

    'makeopts':
      content => $makeopts,
    ;

    'emerge_default_opts':
      ensure  => $emerge_default_opts_ensure,
      content => $facts['emerge_default_opts'],
    ;
  }

  # Don't timeout rebuilding packages
  Exec <| title == 'changed_makeconf' |> {
    timeout => 0,
  }



  #
  # Repositories
  #
  file { '/etc/portage/repos.conf':
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    purge   => true,
    recurse => true,
    force   => true,
  }

  nest::lib::repo {
    'gentoo':
      url     => 'https://gitlab.james.tl/nest/gentoo/portage.git',
      default => true,
    ;

    'nest':
      url      => 'https://gitlab.james.tl/nest/overlay.git',
      unstable => true,
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
    command     => '/usr/bin/eix-update -q',
    refreshonly => true,
  }



  #
  # Package environments and properties
  #
  $cflags_no_crypto_ensure = $cflags_no_crypto ? {
    $facts['portage_cflags'] => 'absent',
    default                  => 'present',
  }

  $cflags_no_crypto = regsubst($facts['portage_cflags'], '\+crypto(\s|$)', '')
  $cflags_no_debug  = regsubst($facts['portage_cflags'], '\s?-g(gdb)?(\s|$)', '')

  file {
    default:
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      before => Class['::portage'],
    ;

    '/etc/portage/env':
      ensure => directory,
    ;

    '/etc/portage/env/no-crypto.conf':
      ensure  => $cflags_no_crypto_ensure,
      content => "CFLAGS='${cflags_no_crypto}'\nCXXFLAGS='${cflags_no_crypto}'\n",
    ;

    '/etc/portage/env/no-debug.conf':
      content => "CFLAGS='${cflags_no_debug}'\nCXXFLAGS='${cflags_no_debug}'\n",
    ;
  }

  # xvid incorrectly passes `-mcpu` as `-mtune` which doesn't accept `+crypto`
  package_env { 'media-libs/xvid':
    ensure => $cflags_no_crypto_ensure,
    env    => 'no-crypto.conf',
  }

  # Create portage package properties rebuild affected packages
  create_resources(package_accept_keywords, $::nest::package_keywords_hiera, { 'before' => Class['::portage'] })
  create_resources(package_env, $::nest::package_env_hiera, { 'before' => Class['::portage'] })

  # Purge unmanaged portage package properties
  resources {
    default:
      purge => true,
    ;

    'package_accept_keywords':
      before => Class['::portage'],
    ;

    'package_env':
      before => Class['::portage'],
    ;
  }

  file { '/etc/portage/patches':
    ensure  => directory,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/nest/portage/patches',
    recurse => true,
    force   => true,
    purge   => true,
  }



  #
  # XXX: Removals
  #
  portage::makeconf { [
    'accept_license',
    'cflags',
    'cxxflags',
    'cpu_flags_x86',
    'distdir',
    'input_devices',
    'pkgdir',
    'use',
    'video_cards',
  ]:
    ensure => absent,
  }

  file { [
    '/etc/eix-sync.conf',
    '/etc/eixrc/10-disable-statusline',
    '/etc/portage/env/heavy.conf',
    '/etc/portage/env/heavier.conf',
    '/etc/portage/env/heaviest.conf',
    '/etc/portage/env/light-debug.conf',
    '/etc/portage/package.use/default',
    '/etc/portage/profile',
  ]:
    ensure  => absent,
    recurse => true,
    force   => true,
  }
}
