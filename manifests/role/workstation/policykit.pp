class nest::role::workstation::policykit {
  $admin_rules_content = @(EOT)
    polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel")) {
            return polkit.Result.YES;
        }
    });
    | EOT

  file { '/etc/polkit-1/rules.d/10-admin.rules':
    mode    => '0644',
    owner   => 'polkitd',
    group   => 'root',
    content => $admin_rules_content,
  }
}
