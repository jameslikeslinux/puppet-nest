define postfix::conf (
    $content = undef,
    $source  = undef,
    $order   = undef,
) {
    concat::fragment { "postfix-conf-${name}":
        target  => 'postfix-main.cf',
        content => $content,
        source  => $source,
        order   => $order,
    }
}
