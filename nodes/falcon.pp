node 'falcon' {
    class { 'profile::base':
        remote_backup    => true,
        disk_id          => '/dev/disk/by-id/ata-Samsung_SSD_840_PRO_Series_S1ATNSAD908564X',
        disk_profile     => crypt,
        video_cards      => ['nouveau'],
        package_server   => 'http://packages.thestaticvoid.com/',
        roles            => [
            cachefiles,
            desktop,
            qemu_chroot,
            terminal_client,
            virtualbox,
            work_system,
        ],
    }

    class { 'inkscape': }
}

@host { 'falcon':
    ip => '172.22.2.4',
}

@sshkey { 'falcon':
    type => 'ssh-dss',
    key  => 'AAAAB3NzaC1kc3MAAACBALj8uXaEIh+NsLXCCFzrHQq5MF78fqAIJ9m/q4n3GgLUBYZCgWqvn3kfCCaAX01ngLaOv0GBTfVCd/6LOeiVJZo/ddWG2AGx9ue1t1M48mYFeNw1jtC+UzCIRlFY0+zE4qBEb3cMoZokrU5v3GodDPzQ2rXLszZ6QK9laE/7dRbxAAAAFQC92R8NRO7dC3Ne6a1eAkirizLyQQAAAIBB7Kr0am9jGB9Az2yoR34w2B6c3eegzRNG81vNcJdVCCXSVchFshhkyVf+Vcu2ZT+aFwUS+5x8svwneUxSSwbBc3Vk4yzb3iZCQC+o8TdOS0BYNujGXbDzj9cll4HoBYRHb/4wBTGWvY9Zo1FpvrRZih2ECFQkfpJV6PO37dQ+2QAAAIBc7jrWglFk2T+xV6eMl5KiVo7l/WS8S1MhDHYapvNLR8imMcL1x7wvKEsxlFDTANVdSd2qqWN8LvCoyCGlsU7Z4tCFJTjbIa6fAwRpJkB4gD2QDUNvA3IB+Ck4hQTu6vR5VtS0vuDbTtdo5rbWrbLNEq6+4Gl3Ao16+YqI8CEPnA==',
}
