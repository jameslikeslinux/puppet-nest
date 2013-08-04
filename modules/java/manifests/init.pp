class java (
    $nsplugin = false,
) {
    portage::package { 'dev-java/oracle-jdk-bin':
        use => $nsplugin ? {
            false   => undef,
            default => 'nsplugin',
        }
    }
}
