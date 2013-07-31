class kde::agents {
    file { '/etc/kde/startup/agent-startup.sh':
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/kde/agent-startup.sh',
    }

    file { '/etc/kde/shutdown/agent-shutdown.sh':
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
        source => 'puppet:///modules/kde/agent-shutdown.sh',
    }

    Class['kde'] -> Class['kde::agents']
}
