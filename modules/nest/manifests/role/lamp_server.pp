class nest::role::lamp_server {
    unless web_server in $nest::roles {
        fail("Must have 'web_server' role to be 'lamp_server'")
    }

    class { 'private::nest::role::lamp_server': }

    class { 'mysql':
        password => $private::nest::role::lamp_server::mysql_password,
    }

    class { 'php':
        timezone => $nest::timezone,
        apache   => true,
        mysql    => true,
    }
}
