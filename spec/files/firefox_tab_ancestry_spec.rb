require 'open3'
require 'spec_helper'

RSpec.describe 'Firefox browser chrome tab ancestry' do
  let(:repo_root) { File.expand_path('../..', __dir__) }

  it 'separates page widgets from chrome and preserves fail-closed workflow targeting' do
    test_path = File.join(repo_root, 'spec/app/hermes/test_firefox_tab_ancestry.py')
    stdout, stderr, status = Open3.capture3({ 'PYTHONDONTWRITEBYTECODE' => '1' }, 'python3', test_path)

    expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
  end
end
