function nest::firewall_cmd(String $args) >> String {
  "/usr/bin/firewall-cmd --permanent ${args} || /usr/bin/firewall-offline-cmd ${args}"
}
