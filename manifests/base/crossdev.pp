class nest::base::crossdev {
  if $::nest::distcc_server or $::platform == 'pinebookpro' {
    package { 'sys-devel/crossdev':
      ensure => installed,
    }

    file {
      default:
        mode  => '0644',
        owner => 'root',
        group => 'root',
      ;

      [
        '/var/db/repos/crossdev',
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
    ->
    nest::lib::repo { 'crossdev': }

    if $::platform == 'pinebookpro' {
      exec { '/usr/bin/crossdev --stable -s1 -t arm-none-eabi':
        creates => '/usr/bin/arm-none-eabi-gcc',
        timeout => 0,
        require => [
          Package['sys-devel/crossdev'],
          Nest::Lib::Repos['crossdev'],
        ],
      }
    }
  }
}
