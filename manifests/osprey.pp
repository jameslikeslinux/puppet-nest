node 'osprey' {
    class { 'profile::base':
        remote_backup  => true,
        disk_id        => '/dev/vda',
        disk_profile   => crypt,
        distcc         => true,
        keymap         => 'us',
        resolution     => '1024x768',
        video_cards    => ['cirrus'],
        package_server => 'http://hawk/packages/',
        wan            => true,
        roles          => [
            private_stuff,
            lamp_server,
            server,
            thestaticvoid,
            web_server,
        ],
    }
}

@hostname::host { 'osprey':
    ip => '172.22.2.7',
}

@sshkey { 'osprey':
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBANr9MZ0FyHH5uhLGAFkfGOyxwkfSgdd+kYJvz6BmkH8tON/nvnJj36zazWcfGljPlZuXPBU7vL0IM5gS6ZJ5Do1dw553a9ppoJ0cnrO4IDsU1rZ44QkZVE5g60ZNjyZRTZWeZr7HkA36jxruQWgKBGSr6fic007WhM60GRI5EwQ3AAAAFQCiu6SOezngNG0Fy9rZhu596EuXaQAAAIBOINVM++PcA+17agshrKRdxsRSzHxhtFrCxebo2ujD8H7adcDHhByuMfZQjqDVfLhvQZL0fJrg65DTVaj74dUZW2NTgIy73oxdc84mrVdSEXVxC/47PqOO7KUtC2Hc/VT/WF/zzBRrEH26wJVCTCd0vnxQ73W5u5SOZFuj1e3ElAAAAIEAwzyM0Oe6HBx1KUC+xQLps0lNed0f19y99nI30VE0PO0mqhXx7uz58RPfLbhyUEQ2Cp7Q3Nzdsr9gsrWXMfhMHOgZldptdHe/4xfX19uo1+/+lzPxPhdENKoZ0jx5TSNiKGoLsMAmFuIbQLN4kHOY4xskbBlgg84w7S1yp/kjdKk=',
}
