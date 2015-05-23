node 'beaglebone1' {
    class { 'nest':
        arch             => beaglebone,
        disk_profile     => beaglebone,
        distcc           => true,
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
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBAJ3MQQpQHthAHWZeCy7v8twWhrCk0zuH6GO7JA+u6fPPI9EsYicUCuZeVXjFox+SZlIXFNj1IRmaRJyKt8BF3qKDcWHX8sg1mhU1/5rLiCRKp8UraUiQ8iOL9DVvkj+EYv2U/Aqv5UwAAxNQphDlE4ixizxBZu9U6ZnCO0E85j21AAAAFQCUp6+IpI12eCh5cQQAosiB2IGnjwAAAIBJZG6in+4OaGXwECNYH46yZexB/aKNZZjf+NLJ1TBJe3S3eukBI1dTW2nCLCse30xTsKh2/lUTnT7t+ot+pBOM/yQS5iu6l2KI6Oa/6pVcJx7OiZbwc/TVXhyAYl4TJHa/U+wibFe9K2K7QWOOiF5BxAwXFKiy2oELUCDka3EyLQAAAIB9u85uYWMWk40PiAsfgPltBvyIHIsHw/2OgpZBDoeXLAZYWpwDZkoHPr4ZXG2w1YaRHydSlFafyL7FkJbSzLxbHw59zS1CKwU5ezCeg/x7JpiFs6jFfKdt+8MN+bFuVdzYPxTUaWWpYvt2FxLNYZVSP7+PI6UCUGiBOKIAxnawyQ==',
}
