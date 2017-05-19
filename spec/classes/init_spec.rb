require 'spec_helper'
describe 'nest' do
  context 'with default values for all parameters' do
    it { should contain_class('nest') }
  end
end
