class profile::role::virtualbox {
    class { '::virtualbox':
        autostart_users => ['jlee'],
    }
}
