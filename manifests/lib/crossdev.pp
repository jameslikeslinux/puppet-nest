class nest::lib::crossdev {
  package { 'sys-devel/crossdev':
    ensure => installed,
  }
  ->
  file_line { 'crossdev-usepkg':
    path  => '/usr/bin/crossdev',
    line  => 'export EMERGE_DEFAULT_OPTS="--quiet-build=n --usepkg"',
    match => '^export EMERGE_DEFAULT_OPTS=',
  }

  nest::lib::repo { 'crossdev': }

  file {
    default:
      mode  => '0644',
      owner => 'root',
      group => 'root',
    ;

    [
      '/var/db/repos/crossdev/metadata',
      '/var/db/repos/crossdev/profiles',
    ]:
      ensure => directory,
    ;

    '/var/db/repos/crossdev/metadata/layout.conf':
      content => "masters = gentoo\nthin-manifests = true\n",
    ;

    '/var/db/repos/crossdev/profiles/repo_name':
      content => "crossdev\n",
    ;
  }
}
