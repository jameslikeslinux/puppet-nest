Facter.add('is_container') do
  confine kernel: 'Linux'
  setcode do
    Facter::Core::Execution.execute('systemd-detect-virt --container') != 'none'
  end
end
