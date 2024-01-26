Facter.add('zpools_cached') do
  confine kernel: 'Linux'
  setcode do
    if File.exist?('/usr/bin/lsinitrd')
      !Facter::Core::Execution.execute('/usr/bin/lsinitrd -f /etc/zfs/zpool.cache').empty?
    end
  end
end
