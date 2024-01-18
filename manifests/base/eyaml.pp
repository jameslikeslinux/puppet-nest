class nest::base::eyaml {
  case $facts['os']['family'] {
    'Gentoo': {
      $conf_dir = '/etc/eyaml'

      package { 'dev-ruby/hiera-eyaml':
        ensure => installed,
        before => File[$conf_dir],
      }

      File {
        mode  => '0644',
        owner => 'root',
        group => 'root',
      }

      exec { 'make-eyaml-key-readable':
        command => '/usr/sbin/setfacl -m user:james:r /etc/eyaml/keys/private_key.pkcs7.pem',
        unless  => '/usr/sbin/getfacl /etc/eyaml/keys/private_key.pkcs7.pem | /bin/grep "^user:james:r--"',
        require => [
          File['/etc/eyaml/keys/private_key.pkcs7.pem'],
          User['james'],
        ],
      }
    }

    'windows': {
      $conf_dir = 'C:/tools/cygwin/etc/eyaml'

      exec { 'gem-install-hiera-eyaml':
        command     => shellquote(
          'C:/tools/cygwin/bin/bash.exe', '-c',
          '/usr/bin/gem install hiera-eyaml'
        ),
        environment => 'HOME=/home/james',
        creates     => 'C:/tools/cygwin/home/james/bin/eyaml',
        require     => Package['ruby'],
        before      => File[$conf_dir],
      }

      File {
        mode  => '0644',
        owner => 'Administrators',
        group => 'None',
      }
    }
  }

  $eyaml_conf = @(CONF)
    ---
    pkcs7_private_key: '/etc/eyaml/keys/private_key.pkcs7.pem'
    pkcs7_public_key: '/etc/eyaml/keys/public_key.pkcs7.pem'
    | CONF

  if $facts['build'] in [undef, 'stage3'] {
    $eyaml_private_key = $nest::eyaml_private_key
  } else {
    $eyaml_private_key = ''
  }

  file {
    [$conf_dir, "${conf_dir}/keys"]:
      ensure => directory,
    ;

    "${conf_dir}/config.yaml":
      content => $eyaml_conf,
    ;

    "${conf_dir}/keys/public_key.pkcs7.pem":
      content => $nest::eyaml_public_key,
    ;

    "${conf_dir}/keys/private_key.pkcs7.pem":
      mode    => '0640',
      content => $eyaml_private_key,
    ;
  }
}
