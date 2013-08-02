define apache::vhost (
    $content = undef,
    $source  = undef,
) {
    #
    # Don't do anything fancy; just create the configuration for now.
    #
    file { "/etc/apache2/vhosts.d/$name.conf":
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => $content,
        source  => $source,
        require => Portage::Package['www-servers/apache'],
        notify  => Openrc::Service['apache2'],
    }
}
