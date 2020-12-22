Facter.add('is_container') do
  confine :kernel => 'Linux'
  setcode do
    Facter.value(:virtual) == 'lxc' or File.exist? '/run/.containerenv'
  end
end
