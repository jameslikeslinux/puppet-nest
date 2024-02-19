require 'spec_helper'

describe 'nest::base::firmware' do
  let(:pre_condition) { 'class { "nest": dtb_file => "vendor/board.dtb" }' }

  on_supported_os.each do |os, facts|
    case os
    when %r{^gentoo-}
      context 'on Gentoo' do
        let(:facts) do
          facts
        end

        it { is_expected.to contain_file('/boot/vendor/board.dtb').that_requires('Class[nest::base::kernel]') }
        it { is_expected.to contain_class('nest::base::firmware').that_notifies('Class[nest::base::dracut]') }
      end
    end
  end
end
