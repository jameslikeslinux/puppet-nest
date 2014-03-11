class ssh::client {
    Sshkey <| |> {
        require => Class['ssh'],
        before  => File['/etc/ssh/ssh_known_hosts'],
    }

    file { '/etc/ssh/ssh_known_hosts':
        mode  => '0644',
        owner => 'root',
        group => 'root',
    }
}
