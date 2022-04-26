Facter.add('profile') do
  confine osfamily: 'Gentoo'
  setcode do
    profile = Facter::Core::Execution.execute('/usr/bin/eselect --brief profile show')
    case profile
    when %r{nest:(\S+)/(\S+)/(\S+)}
      { cpu: Regexp.last_match(1), platform: Regexp.last_match(2), role: Regexp.last_match(3) }
    when %r{nest:(\S+)/(\S+)}
      { cpu: Regexp.last_match(1), platform: Regexp.last_match(1), role: Regexp.last_match(2) }
    end
  end
end

Facter.add('profile') do
  setcode do
    { role: 'workstation' }
  end
end
