require 'open3'
require 'spec_helper'

RSpec.describe 'Joyride self-service TEST deployment boundary' do
  let(:repo_root) { File.expand_path('../..', __dir__) }

  it 'preserves exact-workload interruption recovery and terminal results' do
    test_path = File.join(repo_root, 'spec/app/joyride/test_delivery_controller.py')
    stdout, stderr, status = Open3.capture3({ 'PYTHONDONTWRITEBYTECODE' => '1' }, 'python3', test_path)

    expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
  end

  it 'checks ordinary CI artifact identity without signing or custody services' do
    test_path = File.join(repo_root, 'spec/app/joyride/test_import_artifacts.py')
    stdout, stderr, status = Open3.capture3({ 'PYTHONDONTWRITEBYTECODE' => '1' }, 'python3', test_path)

    expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
  end
end
