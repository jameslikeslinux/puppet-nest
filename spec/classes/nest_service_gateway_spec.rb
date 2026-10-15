require 'spec_helper'

describe 'nest::service::gateway' do
  on_supported_os.each do |os, facts|
    next unless os.match?(%r{^gentoo-})

    context 'on Gentoo' do
      let(:facts) { facts }
      let(:pre_condition) { 'include nest' }

      context 'with port forwarding only' do
        it { is_expected.to compile }
        it_should_and_should_not_contain_classes(['nest::service::gateway'], ['nest::service::apache', 'apache'])
      end
    end
  end
end
