class tomcat {
    portage::package { 'www-servers/tomcat':
        ensure  => installed,
    }
}
