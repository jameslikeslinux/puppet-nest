define sysctl::setting (
    $value,
) {
    include sysctl

    concat::fragment { "sysctl-setting-${name}":
        target  => '/etc/sysctl.d/local.conf',
        content => "${name} = ${value}\n",
    }
}
