require 'spec_helper'
require 'yaml'

describe 'Hermes broker runtime deployment boundary' do
  let(:root) { File.expand_path('../..', __dir__) }
  let(:owl) { YAML.safe_load_file(File.join(root, 'data/host/owl.yaml'), aliases: true) }
  let(:install) { File.read(File.join(root, 'manifests/app/hermes/install.pp')) }
  let(:tag) { "tag         => 'hermes_agent_request_broker_runtime'" }

  it 'pins the merged broker independently of the Hermes core' do
    expect(owl.fetch('nest::app::hermes::broker_git_ref')).to eq('d188703f9f8b5662ade2572139bdddb429e5c04a')
    expect(owl.fetch('nest::app::hermes::git_ref')).to eq('nest')
    expect(owl.fetch('nest::app::hermes::git_commit')).to eq('1e36895dabf4bb70a187ab9501988fae967d1826')
  end

  it 'restricts the runtime tag to the broker checkout and install' do
    tagged = install.scan(%r{(?:vcsrepo|exec|file) \{ ([^\n]+):\n(.*?)^  \}}m).select { |_title, body| body.include?('hermes_agent_request_broker_runtime') }
    expect(tagged.map(&:first)).to contain_exactly('$broker_source_dir', "'install_hermes_agent_request_broker'")
    expect(tagged.last.last).to include(tag)
    expect(tagged.first.last).to include('revision => $broker_git_ref')
    expect(tagged.last.last).to include('Vcsrepo[$broker_source_dir]')
  end
end
