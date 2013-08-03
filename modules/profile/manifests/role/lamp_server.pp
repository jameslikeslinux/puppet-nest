class profile::role::lamp_server {
    unless web_server in $profile::base::roles {
        fail("Must have 'web_server' role to be 'lamp_server'")
    }

    class { 'private::profile::role::lamp_server': }

    class { 'mysql':
        password => $private::profile::role::lamp_server::mysql_password,
    }

    class { 'php':
        timezone => $profile::base::timezone,
        apache   => true,
        mysql    => true,
    }
}
