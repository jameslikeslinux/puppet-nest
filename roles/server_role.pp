class server_role {
    openrc::service { 'dhcpcd':
        enable => true,
    }
}
