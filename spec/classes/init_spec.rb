require 'spec_helper'
describe 'nest' do
  on_supported_os(facterversion: '2.4').each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }
      it { should compile.with_all_deps }
    end
  end
end
