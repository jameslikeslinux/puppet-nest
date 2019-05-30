Facter.add('rpool') do
  confine :kernel => 'Linux'
  setcode do
    hostname = Facter.value('hostname')
    if File.exist?('/sbin/zfs')
      ["#{hostname}/crypt", hostname].each do |name|
        Facter::Core::Execution.execute("/sbin/zfs list #{name}")
        break name if $? == 0
      end
    else
      hostname
    end
  end
end
