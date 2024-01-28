Facter.add('rpool_hostid') do
  confine kernel: 'Linux'
  setcode do
    if File.exist?('/sbin/zdb')
      rpool = Facter.value('hostname')
      if Facter::Core::Execution.execute("/sbin/zdb -eC #{rpool}") =~ %r{\s*hostid: (\d+)}
        Regexp.last_match(1).to_i.to_s(16)
      end
    end
  end
end
