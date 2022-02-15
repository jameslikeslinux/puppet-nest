Facter.add('kernel_version') do
  confine kernel: 'Linux'
  setcode do
    if File.exist?('/usr/src/linux/Makefile')
      Facter::Core::Execution.execute('/usr/bin/make -s -C /usr/src/linux kernelversion')
    end
  end
end
