class java (
    $nsplugin = false,
    $kde = false,
) {
    portage::package { 'dev-java/oracle-jdk-bin':
        use => $nsplugin ? {
            false   => undef,
            default => 'nsplugin',
        }
    }

    if $kde {
        file { '/etc/kde/startup/java-settings.sh':
            mode    => '0644',
            owner   => 'root',
            group   => 'root',
            source  => 'puppet:///modules/java/java-settings.sh',
            require => Class['kde'],
        }
    }
}
