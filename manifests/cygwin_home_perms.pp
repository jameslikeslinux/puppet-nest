define nest::cygwin_home_perms (
  $user = $name,
) {
  $user_quoted = shellquote($user)

  $exceptions = '-not -path "**/.mozilla/firefox/**" -o -path "**/.mozilla/firefox/default/user.js*" -o -path "**/.mozilla/firefox/default/chrome/userChrome.css"'

  $find_bad_ownership = "find ~${user_quoted} -not \( -user ${user_quoted} -group Administrators \) \( ${exceptions} \)"
  $ownership_ok = "C:/tools/cygwin/bin/bash.exe -c 'source /etc/profile && output=\"\$(${find_bad_ownership})\" && [[ \$output == \"\" ]]'"
  $fix_ownership = "C:/tools/cygwin/bin/bash.exe -c 'source /etc/profile && ${find_bad_ownership} -exec chown -h ${user_quoted}:Administrators {} +'"

  $find_bad_group_perms = "find ~${user_quoted} -perm -g=r -not -perm -g=w"
  $group_perms_ok = "C:/tools/cygwin/bin/bash.exe -c 'source /etc/profile && output=\"\$(${find_bad_group_perms})\" && [[ \$output == \"\" ]]'"
  $fix_group_perms = "C:/tools/cygwin/bin/bash.exe -c 'source /etc/profile && ${find_bad_group_perms} -exec chmod g+w {} +'"

  $find_bad_setgid_dirs = "find ~${user_quoted} -type d -not -perm -g=s"
  $setgid_dirs_ok = "C:/tools/cygwin/bin/bash.exe -c 'source /etc/profile && output=\"\$(${find_bad_setgid_dirs})\" && [[ \$output == \"\" ]]'"
  $fix_setgid_dirs = "C:/tools/cygwin/bin/bash.exe -c 'source /etc/profile && ${find_bad_setgid_dirs} -exec chmod g+s {} +'"

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
