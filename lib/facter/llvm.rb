Facter.add('llvm_clang') do
  confine kernel: 'Linux'
  setcode do
    Facter::Core::Execution.execute('bash -c "source /etc/profile && which clang"')
  end
end

Facter.add('llvm_ld') do
  confine kernel: 'Linux'
  setcode do
    Facter::Core::Execution.execute('bash -c "source /etc/profile && which ld.lld"')
  end
end
