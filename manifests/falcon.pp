node 'falcon' {
    Hostname::Host <| title != $clientcert |>

    Sshkey <| |> {
        target => 'C:/cygwin64/etc/ssh_known_hosts',
    }
}

@hostname::host { 'falcon':
    ip => '172.22.2.4',
}

@sshkey { 'falcon':
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBALHfxoLRRkmyE90PfcVi6j3p2AeDel3X2WnlFK1Hpyope6WerBNiTBbACBnNN2Es8Lj1GFQa+GnXY6TCbENTBNCBGt56jZ7BeaSbyjqlbGXRzozvfbT1B6MUD0gmdv1UvSVJvKfdr1fW/8fc7PLgTJTP6GXkJTzEWMcgNCw9xZhLAAAAFQDU85PQzalj8tyQIzwQO8hMf+p50wAAAIEApj74eoHVie70SuzV3RJ7u1wCw0QVFIUy3tEpXjsqSYX4vALPxKzn2+7AtUhhEETvM69TrK8GBFbExCqZjse3SXupX5J4onee/yAH/D/M+KlDzB5qUrzpRfwkN6PkG0rVIZ0YU5sDD46dpfBKYEBB5ZUX4maShIYCYqXtQ4Z7WnoAAACBAJXJco+kEclxUcT3X7cNPW40/8hlDwLOphBV31N0w5b0/AanCJvHg/cjMzzLuHn2gI2Ir7MbOHD6lU6kQRo/yWwf2FvRjv467S4EvITkJaI6GrO3Xj4dG1Edc3+dsTYHw2XVTGN+hBGna6OmQNM3WMeoEbtd67PGTbh/hzb9N9Wb',
}
