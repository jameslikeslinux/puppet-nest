require 'spec_helper'

describe 'nest::base::console' do
  let(:pre_condition) { 'include nest' }

  on_supported_os.each do |os, facts|
    case os
    when %r{^gentoo-}
      context 'on Gentoo' do
        let(:facts) do
          facts
        end

        it { is_expected.to contain_class('nest::base::console').that_notifies('Class[nest::base::dracut]') }
      end
    end
  end
end
