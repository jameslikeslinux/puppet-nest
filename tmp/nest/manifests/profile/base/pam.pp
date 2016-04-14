class nest::profile::base::pam {
  class use {
    @package_use { 'sys-auth/pambase':
      use => ['pam_krb5', 'pam_ssh'],
    }
  }

  include nest::profile::base::pam::use

  $krb5_conf = @(EOT)
    [libdefaults]
        default_realm = UMD.EDU
        forwardable = yes
    | EOT

  file { '/etc/krb5.conf':
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => $krb5_conf,
  }

  augeas { 'system-auth':
    context => '/files/etc/pam.d/system-auth',
    changes => [
      # Do pam_krb5 before pam_ssh because pam_krb5 is optional
      "ins 01 after *[type = 'auth' and module = 'pam_krb5.so']",
      "mv *[type = 'auth' and module = 'pam_ssh.so'] 01",

      # pam_krb5 is optional
      "setm *[(type = 'auth' or type = 'session') and module = 'pam_krb5.so'] control optional",

      # pam_krb5 should authenticate with the principal listed in ~/.k5login
      "rm *[type = 'auth' and module = 'pam_krb5.so']/argument",
      "set *[type = 'auth' and module = 'pam_krb5.so']/argument search_k5login",

      # pam_ssh should use the password that pam_krb5 asked for
      "rm *[type = 'auth' and module = 'pam_ssh.so']/argument",
      "set *[type = 'auth' and module = 'pam_ssh.so']/argument use_first_pass",

      # pam_krb5 should not have any effect on account status
      # and should not be involved in password changes
      "rm *[(type = 'account' or type = 'password') and module = 'pam_krb5.so']",

      # pam_krb5 session doesn't need any arguments
      "rm *[type = 'session' and module = 'pam_krb5.so']/argument",
    ],
  } 
}
