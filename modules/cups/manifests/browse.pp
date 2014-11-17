define cups::browse {
    include cups

    concat::fragment { "cups-browsed.conf-browse-${name}":
        target  => '/etc/cups/cups-browsed.conf',
        content => template('cups/browse.erb'),
    }
}
