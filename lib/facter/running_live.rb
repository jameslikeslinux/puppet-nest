Facter.add('running_live') do
  confine :kernel => 'Linux'
  setcode do
    Facter.value(:mountpoints)['/']['device'] == '/dev/mapper/live-rw'
  end
end
