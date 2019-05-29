Facter.add('rpool') do
  confine :kernel => 'Linux'
  setcode do
    certname = Facter::Core::Execution.execute('puppet agent --configprint certname').gsub(/\..*/, '')
    ["#{certname}/crypt", certname].each do |name|
      Facter::Core::Execution.execute("zfs list #{name}")
      break name if $? == 0
    end
  end
end
