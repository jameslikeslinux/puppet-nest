define openrc::service (
    $runlevel = 'default',
    $enable   = undef,
    $ensure   = undef,
) {
    case $enable {
        true: {
            exec { "/sbin/rc-update add ${name} ${runlevel}":
                unless => "/bin/rc-status ${runlevel} | /bin/grep ' ${name} '",
                before => Service[$name],
            }
        }

        false: {
            exec { "/sbin/rc-update del ${name} ${runlevel}":
                onlyif => "/bin/rc-status ${runlevel} | /bin/grep ' ${name} '",
                before => Service[$name],
            }
        }

        default: {
            # do nothing
        }
    }

    service { $name:
        enable   => $enable,
        ensure   => $ensure,
        provider => 'openrc',
    }
}
