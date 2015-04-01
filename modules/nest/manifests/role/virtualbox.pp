class nest::role::virtualbox {
    class { '::virtualbox':
        autostart_users => ['jlee'],
    }
}
