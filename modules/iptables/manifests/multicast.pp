class iptables::multicast {
    iptables::rule { 'accept-multicast':
        rule  => '-A INPUT -m pkttype --pkt-type multicast -j ACCEPT',
        order => '15',
    }
}
