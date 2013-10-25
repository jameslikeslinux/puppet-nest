define overlay (
    $target,
) {
    file { [
        $target,
        "${target}/profiles"
    ]:
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
    }

    file { "${target}/profiles/repo_name":
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => "$name\n",
    }
}
