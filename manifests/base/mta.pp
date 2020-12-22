class nest::base::mta {
  package { 'mail-mta/nullmailer':
    ensure => installed,
  }

  unless $facts['build'] == 'stage1' or $facts['tool'] {
    file {
      default:
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        require => Package['mail-mta/nullmailer'],
        notify  => Service['nullmailer'],
      ;

      '/etc/nullmailer/remotes':
        mode      => '0640',
        group     => 'nullmail',
        content   => "${::nest::nullmailer_config}\n",
        show_diff => false,
        notify    => Service['nullmailer'],
      ;

      '/etc/nullmailer/defaultdomain':
        content => "nest\n",
      ;

      '/etc/nullmailer/me':
        content => "${facts['hostname']}\n",
      ;
    }
  }

  service { 'nullmailer':
    enable  => true,
    require => Package['mail-mta/nullmailer'],
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
