Facter.add('release') do
  confine kernel: 'Linux'
  setcode do
    if File.exist?('/etc/os-release')
      ['BUILD_ID', 'IMAGE_ID'].each_with_object({}) do |key, release|
        value = Facter::Core::Execution.execute("/bin/sh -c 'source /etc/os-release && echo \$#{key}'")
        release[key.downcase] = value unless value.empty?
      end
    end
  end
end
