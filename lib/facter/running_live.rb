Facter.add('running_live') do
  confine kernel: 'Linux'
  setcode do
    mountpoints = Facter.value(:mountpoints)
    mountpoints['/']['device'] == 'LiveOS_rootfs' if mountpoints && mountpoints['/']
  end
end
