require 'spec_helper'

describe 'nest::base::dracut' do
  let(:pre_condition) { 'include nest' }

  on_supported_os.each do |os, facts|
    case os
    when %r{^gentoo-}
      context 'on Gentoo' do
        let(:facts) do
          facts
        end

        it { is_expected.to contain_class('nest::base::dracut').that_subscribes_to('Class[nest::base::branding]') }
        it { is_expected.to contain_class('nest::base::dracut').that_subscribes_to('Class[nest::base::zfs]') }
      end
    end
  end
end
