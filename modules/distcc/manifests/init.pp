class distcc (
    $gui = false,
) {
    portage::package { 'sys-devel/distcc':
        ensure => installed,
        use    => $gui ? {
            false   => undef,
            default => 'gtk',
        }
    }    
}
