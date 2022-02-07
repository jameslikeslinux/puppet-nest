class nest::base::syslog {
  case $facts['os']['family'] {
    'windows': {
      package { 'syslog-ng':
        ensure   => installed,
        provider => cygwin,
      }
      ->
      exec { 'syslog-ng-config':
        command => shellquote(
          'C:/tools/cygwin/bin/bash.exe', '-c',
          'source /etc/profile && /usr/bin/syslog-ng-config --yes'
        ),
        creates => 'C:/tools/cygwin/etc/syslog-ng/syslog-ng.conf',
      }
      ~>
      service { 'syslog-ng':
        ensure => running,
        enable => true,
      }
    }
  }
}
