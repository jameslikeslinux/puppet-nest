node 'beaglebone1' {
    class { 'nest':
        arch             => beaglebone,
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
    key  => 'AAAAB3NzaC1kc3MAAACBAIlUsYqe9hznARjgWwHsAr+xheI7py1JKaTKIbk+HY4cfGpe8kudEj3vUPBBE8pSSpirmLYVEUWhtVQbq3MPfB2yf4+FZjllMi9dm4NCDamRohKzQSAPr8rjGXZm/WA2qaEr3Cy2hEwNV7mVgng7r/MlRQGZnJvO1ko7YpaGVVpBAAAAFQDVLumX5GAKP0DOf5yZ4Soe0suGJwAAAIBrumji1vQMlVn9QdsqgqShdEKI7wlwZk5ma1NFQHbk15uLOXJDwacG27ytDQLx6aAyjVZ0qlmoAhxezqLoEj88m11bD3bg+xbzbzc3jEAMdByLddOdh1/MvK42B3KwzmKwTkEh0xibAiVXXi5PR7QZricZmRFRx+NJASbjzmcRAgAAAIB+UEyjxpKQkEYlnEgUoZumSK2Dxl6rfQ3iYc93/xov6xp4kfEYtiby2qgiaRVAg7qistSNJhdOcrEYFWkY0ry5R7p59yY6i2rm2Qds2pFij4ovwd1yCyXsV9XhF0jxv/qW4wLqRE6czh/+ZYifczGTH/40m830Nw5KNhNyzgHYjw==',
}
