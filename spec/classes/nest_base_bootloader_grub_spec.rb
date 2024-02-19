require 'spec_helper'

describe 'nest::base::bootloader::grub' do
  let(:pre_condition) { 'class { "nest": bootloader => grub }' }

  on_supported_os.each do |os, facts|
    case os
    when %r{^gentoo-}
      context 'on Gentoo' do
        let(:facts) do
          facts
        end

        it { is_expected.to contain_exec('dracut').that_subscribes_to('Class[nest::base::dracut]') }
      end
    end
  end
end
