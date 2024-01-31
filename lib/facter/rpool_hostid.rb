Facter.add('rpool_hostid') do
  confine kernel: 'Linux'
  setcode do
    if File.exist?('/sbin/zdb')
      rpool = Facter.value('hostname')
      if Facter::Core::Execution.execute("/sbin/zdb -C #{rpool} || /sbin/zdb -eC #{rpool}") =~ %r{\s*hostid: (\d+)}
        '%08x' % [Regexp.last_match(1).to_i]
      end
    end
  end
end
