# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'yaml'

RSpec.describe 'kubeadm API-only InitConfiguration integration' do
  let(:script) { File.expand_path('../../files/kubernetes/append-kubeadm-init-config.rb', __dir__) }

  ['v1beta3', 'v1beta4'].each do |version|
    it "preserves the member endpoint and config-based patches with #{version}" do
      Dir.mktmpdir do |directory|
        config = File.join(directory, 'config.yaml')
        manifest = File.join(directory, 'apiserver.yaml')
        cluster = { 'kind' => 'ClusterConfiguration', 'apiVersion' => "kubeadm.k8s.io/#{version}", 'clusterName' => 'integration' }
        File.write(config, YAML.dump(cluster))
        pod = { 'spec' => { 'containers' => [{
          'name' => 'kube-apiserver', 'command' => ['kube-apiserver', '--advertise-address=192.0.2.3', '--secure-port=6443'],
        }] } }
        File.write(manifest, YAML.dump(pod))
        _stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, config, manifest, '/etc/kubernetes/patches')
        expect(status).to be_success, stderr
        documents = YAML.load_stream(File.read(config))
        expect(documents.first).to eq(cluster)
        expected_init = {
          'apiVersion' => "kubeadm.k8s.io/#{version}",
          'kind' => 'InitConfiguration',
          'localAPIEndpoint' => { 'advertiseAddress' => '192.0.2.3', 'bindPort' => 6443 },
          'patches' => { 'directory' => '/etc/kubernetes/patches' },
        }
        expect(documents.last).to eq(expected_init)
      end
    end
  end
end
