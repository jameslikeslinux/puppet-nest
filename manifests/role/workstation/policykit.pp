class nest::role::workstation::policykit {
  $admin_rules_content = @(EOT)
    polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel")) {
            return polkit.Result.YES;
        }
    });
    | EOT

  file {
    default:
      owner   => 'polkitd',
      group   => 'root',
    ;

    '/etc/polkit-1/rules.d':
      mode   => '0700',
      ensure => directory,
    ;

    '/etc/polkit-1/rules.d/10-admin.rules':
      mode    => '0644',
      content => $admin_rules_content,
    ;
  }
}
