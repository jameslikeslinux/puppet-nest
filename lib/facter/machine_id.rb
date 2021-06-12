Facter.add('machine_id') do
  confine kernel: 'Linux'
  setcode do
    if File.exist?('/etc/machine-id')
      File.readlines('/etc/machine-id').map(&:chomp).first
    end
  end
end
