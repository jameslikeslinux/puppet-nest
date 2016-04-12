class nest::profile::base::pam {
  nest::portage::package_use { 'sys-auth/pambase':
    use => ['pam_krb5', 'pam_ssh'],
  }

  file { '/etc/krb5.conf':
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => 'puppet:///modules/nest/pam/krb5.conf',
  }

  file { '/etc/pam.d/system-auth':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    source  => 'puppet:///modules/nest/pam/system-auth',
    require => Nest::Portage::Package_use['sys-auth/pambase'],
  }
}
