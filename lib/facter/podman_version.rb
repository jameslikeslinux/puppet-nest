Facter.add('podman_version') do
  confine :kernel => 'Linux'
  setcode do
    if File.exist?('/usr/bin/podman')
      $1 if Facter::Core::Execution.execute('/usr/bin/podman --version') =~ /podman version (\S+)/
    end
  end
end
