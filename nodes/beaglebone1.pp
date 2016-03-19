node 'beaglebone1' {
    class { 'nest':
        arch             => beaglebone,
        distcc           => true,
        serial_console   => '0',
        roles            => [
            package_server,
            web_server,
        ],
    }
}

@openvpn::host { 'beaglebone1':
    ip => '172.22.2.9',
}

@sshkey { 'beaglebone1':
    type => 'ssh-rsa',
    key  => 'AAAAB3NzaC1yc2EAAAADAQABAAABAQDYSxWGu/bnz82SgX3ApnhkuNps8ONqBqfFn0ZKEbsGS5/u1Qg/XCt6oXr8KESxxg2YKdHYqQjQfP8pJ7lmBS6mqOS8aAchgy4Bv4a4yzU/8ZC5PSXxd7sYhg0RWpQwPImikPpmLvl7Xe434ONkgNA+6VFl9n8EGcruc+kc8fxx/cD+MS4gfD2KXkYEY6IkoLjwQtqAJ7PirwSKrKr360oK63wKpS5SlLgcMFKfi/r12dFLqPND6tVCExY0mxNL2WGxKBLPHhBNPX8uW92LO6iKljT8f71o0aYePb3jIu9lOMpQNmz3UXvKbMk3muZho3KZsfY4XJiNnR7JvvWCusa1',
}
