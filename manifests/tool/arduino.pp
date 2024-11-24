class nest::tool::arduino {
  Exec {
    environment => ['HOME=/root'],
  }

  # Based on https://arduino.github.io/arduino-cli/1.1/installation/
  exec { 'arduino-cli-install':
    command => '/usr/bin/curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | /bin/sh',
    cwd     => '/usr/local',
    creates => '/usr/local/bin/arduino-cli',
  }
  ~>
  exec { 'arduiro-cli-core-update-index':
    command     => '/usr/local/bin/arduino-cli core update-index',
    refreshonly => true,
  }

  exec { 'arduiro-cli-core-install-avr':
    command => '/usr/local/bin/arduino-cli core install arduino:avr',
    timeout => '3600', # 1 hour
    unless  => '/usr/local/bin/arduino-cli core list | /bin/grep "^arduino:avr "',
  }
}
