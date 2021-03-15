Facter.add('running_live') do
  confine :kernel => 'Linux'
  setcode do
    Facter.value(:mountpoints)['/']['device'] == 'LiveOS_rootfs'
  end
end
