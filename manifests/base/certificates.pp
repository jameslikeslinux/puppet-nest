class nest::base::certificates {
  case $facts['os']['family'] {
    'Gentoo': {
      # See: https://wiki.gentoo.org/wiki/Certificates
      file { [
        '/usr/local/share',
        '/usr/local/share/ca-certificates',
      ]:
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
      }

      file { '/usr/local/share/ca-certificates/Eyrie_Root_CA.crt':
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/nest/certificates/Eyrie_Root_CA.crt',
      }
      ~>
      exec { 'update-ca-certificates':
        command     => '/usr/sbin/update-ca-certificates',
        refreshonly => true,
      }
    }

    'windows': {
      $eyrie_root_ca = 'C:/tools/cygwin/etc/pki/ca-trust/source/anchors/Eyrie_Root_CA.crt'

      file { $eyrie_root_ca:
        mode   => '0644',
        owner  => 'Administrators',
        group  => 'None',
        source => 'puppet:///modules/nest/certificates/Eyrie_Root_CA.crt',
      }
      ~>
      exec { 'update-ca-trust':
        command     => shellquote(
          'C:/tools/cygwin/bin/bash.exe', '-c',
          'source /etc/profile && /usr/bin/update-ca-trust'
        ),
        refreshonly => true,
      }

      exec { 'certutil-addstore-eyrie-root':
        command  => "C:/Windows/System32/certutil.exe -addstore Root ${eyrie_root_ca}",
        unless   => "if ((C:/Windows/System32/certutil.exe -verify ${eyrie_root_ca} | Select-String -Pattern UNTRUSTED).Length -gt 0) { exit 1 }",
        require  => File['C:/tools/cygwin/etc/pki/ca-trust/source/anchors/Eyrie_Root_CA.crt'],
        provider => powershell,
      }
    }
  }
}
