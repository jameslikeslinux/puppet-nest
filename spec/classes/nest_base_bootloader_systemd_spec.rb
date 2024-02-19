require 'spec_helper'

describe 'nest::base::bootloader::systemd' do
  let(:pre_condition) { 'class { "nest": bootloader => systemd }' }

  on_supported_os.each do |os, facts|
    case os
    when %r{^gentoo-}
      context 'on Gentoo' do
        let(:facts) do
          facts
        end

        it { is_expected.to contain_exec('kernel-install').that_subscribes_to('Class[nest::base::dracut]') }
      end
    end
  end
end
