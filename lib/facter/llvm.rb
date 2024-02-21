Facter.add('llvm_clang') do
  confine kernel: 'Linux'
  setcode do
    clang = Facter::Core::Execution.execute('bash -c "source /etc/profile && which clang"')
    clang unless clang.empty?
  end
end

Facter.add('llvm_ld') do
  confine kernel: 'Linux'
  setcode do
    ld = Facter::Core::Execution.execute('bash -c "source /etc/profile && which ld.lld"')
    ld unless ld.empty?
  end
end
