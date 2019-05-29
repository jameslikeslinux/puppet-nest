Facter.add('crypt') do
  confine :kernel => 'Linux'
  setcode do
    certname = Facter::Core::Execution.execute('puppet agent --configprint certname').gsub(/\..*/, '')
    Facter::Core::Execution.execute("zfs list #{certname}/crypt")
    $? == 0
  end
end
