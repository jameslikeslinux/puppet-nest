define nest::cygwin_home_perms (
  $user = $name,
) {
  $user_quoted = shellquote($user)

  $find_bad_ownership = "find ~${user_quoted} -not \( -user ${user_quoted} -group Administrators \)"
  $ownership_ok = shellquote(
    'C:/tools/cygwin/bin/bash.exe', '-c',
    "source /etc/profile && output=\"\$(${find_bad_ownership})\" && [[ \$output == '' ]]"
  )
  $fix_ownership = shellquote(
    'C:/tools/cygwin/bin/bash.exe', '-c',
    "source /etc/profile && ${find_bad_ownership} -exec chown -h ${user_quoted}:Administrators {} +"
  )

  $find_bad_group_perms = "find ~${user_quoted} -not -perm -g=w"
  $group_perms_ok = shellquote(
    'C:/tools/cygwin/bin/bash.exe', '-c',
    "source /etc/profile && output=\"\$(${find_bad_group_perms})\" && [[ \$output == '' ]]"
  )
  $fix_group_perms = shellquote(
    'C:/tools/cygwin/bin/bash.exe', '-c',
    "source /etc/profile && ${find_bad_group_perms} -exec chmod g+w {} +"
  )

  $find_bad_setgid_dirs = "find ~${user_quoted} -type d -not -perm -g=s"
  $setgid_dirs_ok = shellquote(
    'C:/tools/cygwin/bin/bash.exe', '-c',
    "source /etc/profile && output=\"\$(${find_bad_setgid_dirs})\" && [[ \$output == '' ]]"
  )
  $fix_setgid_dirs = shellquote(
    'C:/tools/cygwin/bin/bash.exe', '-c',
    "source /etc/profile && ${find_bad_setgid_dirs} -exec chmod g+s {} +"
  )

  exec {
    "fix-cygwin-home-ownership-${title}":
      command => $fix_ownership,
      unless  => $ownership_ok,
    ;

    "fix-cygwin-home-group-perms-${title}":
      command => $fix_group_perms,
      unless  => $group_perms_ok,
      require => Exec["fix-cygwin-home-ownership-${title}"],
    ;

    "fix-cygwin-home-setgid-dirs-${title}":
      command => $fix_setgid_dirs,
      unless  => $setgid_dirs_ok,
      require => Exec["fix-cygwin-home-group-perms-${title}"],
    ;
  }
}
