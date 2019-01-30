class nest::profile::workstation::policykit {
  $admin_rules_content = @(EOT)
    polkit.addAdminRule(function(action, subject) {
        return ["unix-group:wheel"];
    });
    | EOT

  file { '/etc/polkit-1/rules.d/10-admin.rules':
    mode    => '0644',
    owner   => 'polkitd',
    group   => 'root',
    content => $admin_rules_content,
  }
}
