Facter.add('crypt') do
  confine :kernel => 'Linux'
  setcode do
    hostname = Facter.value('hostname')
    Facter::Core::Execution.execute("zfs list #{hostname}/crypt")
    $? == 0
  end
end
