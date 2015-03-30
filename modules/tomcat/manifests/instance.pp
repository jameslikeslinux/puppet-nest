define tomcat::instance (
    $user  = 'tomcat',
    $group = 'tomcat',
) {
    exec { "create-tomcat-instance-${name}":
        command => "/usr/share/tomcat-8/gentoo/tomcat-instance-manager.bash --create --suffix '${name}' --user '${user}' --group '${group}'",
        creates => "/etc/init.d/tomcat-8-${name}",
        require => Class['tomcat'],
    }
}
