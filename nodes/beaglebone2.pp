node 'beaglebone2' {
    class { 'profile::base':
        arch             => beaglebone,
        disk_profile     => beaglebone,
        distcc           => false,
        roles            => [
            package_server,
            web_server,
        ],
    }
}

@hostname::host { 'beaglebone2':
    ip => '172.22.2.11',
}

@sshkey { 'beaglebone2':
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBAK0WPbmUdlPnv3JE4I69zI+ZazLGEdd1Ez1lG/e4xaQV4Bfzy4+BkodtUSI/IyogbN0dgjsDUJxbLDAooR+ElM88/ggnKDF4Me3A1/mpzg+csGtOa/AX8bnr30hSxKHgD/sF0o3xjiqfl7SwNNbx3NgPgKroS+B6cWVPRGUZU4epAAAAFQCEd3R4/XTMB/lmGr0qlmbWrKNeZQAAAIEAosrs6P3I8qt7crm19gDxPKia4Pkgu+w8se+9LHbYrrwbHl9EJr7dXJiJX2S93ChALUbNxVoXSIwFjWEc+KZMdlr9p6RcbjQLVgcDtXiHw9ADRoSgzjZQKPVb8tQf+P6GNrhtvw40Sbuin61HKBIlZVL19mggCgTx7dBupbWQ/IIAAACAB8jrPoNNUM9yt0AnKTVKpGbo0D3gocRQmW5qB8lg4tqVxU8/rr/7MGXxJ4PjBedveCkxAF5j+x8u+BDOCspFM+mgruY65cpRZqeJ3oJBCBvkhUG2uAH/KzE3wvU9AX2YVI0Lo6W6YjfMGevJxn9lpCztwhFaIpHEmadydN2ez0E=',
}
