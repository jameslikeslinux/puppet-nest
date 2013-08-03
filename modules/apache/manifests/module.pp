define apache::module (
    $order   = '99',   
    $source  = undef,
    $content = undef,
) {
    #
    # Don't do anything fancy; just create the configuration for now.
    #
    file { "/etc/apache2/modules.d/${order}_${name}.conf":
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => $content,
        source  => $source,
        require => Portage::Package['www-servers/apache'],
        notify  => Openrc::Service['apache2'],
    }
}
