Facter.add('hostid') do
  confine kernel: 'Linux'
  setcode do
    if File.exist?('/etc/hostid')
      File.read('/etc/hostid').reverse.unpack('H*').first
    end
  end
end
