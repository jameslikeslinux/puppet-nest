class nest::base::mta {
  package { 'mail-mta/nullmailer':
    ensure => installed,
  }

  file { '/etc/nullmailer/remotes':
    mode      => '0640',
    owner     => 'root',
    group     => 'nullmail',
    content   => "${::nest::nullmailer_config}\n",
    show_diff => false,
    require   => Package['mail-mta/nullmailer'],
  }

  service { 'nullmailer':
    enable    => true,
    subscribe => File['/etc/nullmailer/remotes'],
  }

  package { 'net-mail/mailbase':
    ensure => installed,
  }

  mailalias { 'root':
    recipient => $::nest::root_mail_alias,
    target    => '/etc/mail/aliases',
    require   => Package['net-mail/mailbase'],
  }
}
