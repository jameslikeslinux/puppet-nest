class distcc::client (
    $servers,
) {
    include distcc

    file { '/etc/distcc/hosts':
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        content => template('distcc/hosts.erb'),
        require => Class['distcc'],
    }

    file { "/usr/lib/distcc/bin/${toolchain}-wrapper":
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => template('distcc/wrapper.sh.erb'),
        require => Class['distcc'],
    }

    file { [
        '/usr/lib/distcc/bin/c++',
        '/usr/lib/distcc/bin/cc',
        '/usr/lib/distcc/bin/g++',
        '/usr/lib/distcc/bin/gcc',
    ]:
        ensure  => link,
        target  => "/usr/lib/distcc/bin/${toolchain}-wrapper",
        require => File["/usr/lib/distcc/bin/${toolchain}-wrapper"],
    }
}
