node 'falcon' {
    class { 'openvpn::hosts': }

    file { 'C:/cygwin64/etc/ssh_known_hosts':
        owner => 'Administrator',
        group => 'Administrators',
        mode  => '0644',
    }

    Sshkey <| |> {
        target  => 'C:/cygwin64/etc/ssh_known_hosts',
        require => File['C:/cygwin64/etc/ssh_known_hosts'],
    }
}

@openvpn::host { 'falcon':
    ip => '172.22.2.4',
}

@sshkey { 'falcon':
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBAK1bDB1gIVX0ZC0BdqQNzX8HVA8PjB0FGAfHRimga+gNavxvQMDcuLcRIspXFdMUpEjwQmQRZFaxTz/ZYi2xqtb6m349glvGJIKxyKurtO6VLEGOyNsP8wZo4UBNzttPL0Id2dAgVs6MpDtKEw/rkitl8nk0rkX5pxQKF/uGHIGnAAAAFQCu3+sXy02Up8vq1f9qy4jCKgUNnwAAAIAz0M4zOnGbsw1qKkivHtNp/XnFx8ZH57S5ylcPjb4WLM8GKpUMjc1TbvR9ujHCY1GunEM+wdeKHyE4HhIGxCzBZ7UoxaGZvZdBlpwKB7PuANA+Ne+UZaSNxZlLj/a9/UvxUrElzPTZD/ysoW9JpSGExuwp5Mr1aopF0MB0iiP2+wAAAIBo2zRBnTLieiAD2MgqAFLhf6APv8c/4qKLn6Pwm6DFIIPejLGzynn6U9xF2M7IUFHdeWMykSiWEMkfJsGl1+utaZ4WDe4j1B2ku/Q6k0YfySpa5yaEolLh2al/eaGDr4tIwTOu3eGgLAXpTI8vpDBJA9y/Vcxi1RnaCFFUA2wUfw==',
}
