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
      owner => 'polkitd',
      group => 'root',
    ;

    '/etc/polkit-1':
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
    ;

    '/etc/polkit-1/rules.d':
      ensure => directory,
      mode   => '0700',
    ;

    '/etc/polkit-1/rules.d/10-admin.rules':
      mode    => '0644',
      content => $admin_rules_content,
    ;
  }
}
