class java (
    $nsplugin = false,
) {
    portage::package { 'dev-java/oracle-jdk-bin':
        use => $nsplugin ? {
            false   => undef,
            default => 'nsplugin',
        }
    }

    file { '/etc/profile.d/java-options.sh':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/java/java-options.sh',
    }
}
