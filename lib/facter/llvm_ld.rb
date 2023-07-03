Facter.add('llvm_ld') do
  confine kernel: 'Linux'
  setcode do
    Facter::Core::Execution.execute('which ld.lld')
  end
end
