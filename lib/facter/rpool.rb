Facter.add('rpool') do
  confine kernel: 'Linux'
  setcode do
    hostname = Facter.value('hostname')
    if File.exist?('/sbin/zfs')
      require 'English'
      ["#{hostname}/crypt", hostname].find do |name|
        Facter::Core::Execution.execute("/sbin/zfs list #{name}")
        $CHILD_STATUS == 0
      end
    else
      hostname
    end
  end
end
