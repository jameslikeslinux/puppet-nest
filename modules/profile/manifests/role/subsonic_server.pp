class profile::role::subsonic_server {
    class { 'tomcat':
        # require java so that tomcat doesn't pull in OpenJDK
        require => Class['java'],
    }

    class { 'subsonic':
        enable => false,
    }
}
