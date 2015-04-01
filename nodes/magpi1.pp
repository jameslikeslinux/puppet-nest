node 'magpi1' {
    class { 'profile::base':
        arch             => raspberrypi,
        disk_profile     => raspberrypi,
        distcc           => true,
        roles            => [
            package_server,
            web_server,
        ],
    }
}

@hostname::host { 'magpi1':
    ip => '172.22.2.8',
}

@sshkey { 'magpi1':
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBANuuEwy5Xvu5ca1lyZ1SeN1QwIDl+0YjXnZ/btzMhku+ZahHNMN3ifEshdKtyYUNBOMYV33mTJ9R37izi8oYWtJ5e7Isi+dQUINfcruHztQpDbknqgPSlNxG7CPVacce1HMUzSfTpGQitiMYIV+Ldhz7WkBD3+yDoZZeYZrDlgv5AAAAFQD14epVGHbHnvFwrCvlLBP25AAp3QAAAIBPr29aAfbv95ft6y+M7C+7dK9k9zefFkPpV71+uQJgpFoXPle8MnQChfe0U2cbJkBsLSWu4QHEmPXTVwGXLYCRF+Z1JVDhrlguz47ZfnVhDrOcYpCvLNGYCikDTkRtU1vhRfA4hzdP3u6ZTYMo8tQIJpE5YmZeIwt0yfcWODL+3gAAAIBDC5KubVIOTyqog1TQYT8df52sgngAYQzpBoh/cNMvyy/Zw+lh/THk+BbamGdrzf+sUuvWhxS3BopsaEhG8GfBddtF0wporHuhccjc1UN29blxaJ4RDkfNakWh6fsqdrs8L6QmDoRW+WPHqKVrLMfn2AhsV7Q3qrJqln5LYZP38Q==',
}
