Facter.add('is_container') do
  confine kernel: 'Linux'
  setcode do
    Facter.value(:virtual) == 'lxc' || File.exist?('/run/.containerenv') || File.exist?('/run/host/container-manager')
  end
end
