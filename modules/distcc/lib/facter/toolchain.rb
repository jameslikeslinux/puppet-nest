Facter.add('toolchain') do
    setcode do
        # Example:
        # x86_64-pc-linux-gnu-4.6.4 -> x86_64-pc-linux-gnu
        $1 if Facter::Util::Resolution.exec('/usr/bin/gcc-config --get-current-profile') =~ /(.*)-[^-]*$/
    end
end
