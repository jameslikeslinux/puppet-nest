class nest::base::mta {
  case $::nest::mta {
    'nullmailer': {
      class { 'nest::base::mta::postfix':
        ensure => absent,
      }
      ->
      class { 'nest::base::mta::nullmailer':
        ensure => present,
      }
    }

    'postfix': {
      class { 'nest::base::mta::nullmailer':
        ensure => absent,
      }
      ->
      class { 'nest::base::mta::postfix':
        ensure => present,
      }
    }
  }

  package { 'mail-client/mailx':
    ensure => installed,
  }
}
