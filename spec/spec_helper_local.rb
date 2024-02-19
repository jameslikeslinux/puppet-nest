# frozen_string_literal: true

def it_should_and_should_not_contain_classes(should, should_not)
  should.each do |c|
    it { is_expected.to contain_class(c) }
  end

  (should_not - should).each do |c|
    it { is_expected.not_to contain_class(c) }
  end
end
