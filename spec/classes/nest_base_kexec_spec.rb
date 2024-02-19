require 'spec_helper'

describe 'nest::base::kexec' do
  let(:pre_condition) { 'include nest' }

  on_supported_os.each do |os, facts|
    case os
    when %r{^gentoo-}
      context 'on Gentoo' do
        let(:facts) do
          facts
        end

        context 'and kexec => true' do
          let(:pre_condition) { 'class { "nest": kexec => true }' }

          it { is_expected.to contain_service('kexec-load').that_subscribes_to('Class[nest::base::bootloader]') }
        end

        context 'and kexec => false' do
          let(:pre_condition) { 'class { "nest": kexec => false }' }

          it { is_expected.to contain_service('kexec-load').with({ 'ensure' => 'stopped', 'enable' => false }) }
        end
      end
    end
  end
end
