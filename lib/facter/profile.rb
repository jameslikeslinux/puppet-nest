Facter.add('profile') do
  confine :osfamily => 'Gentoo'
  setcode do
    if Facter::Core::Execution.execute('/usr/bin/eselect --brief profile show') =~ %r{nest:(\S+)/(\S+)}
      { :platform => $1, :role => $2 }
    end
  end
end
