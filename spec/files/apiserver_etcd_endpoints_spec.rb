# frozen_string_literal: true

require 'json'
require 'yaml'
require 'open3'
require 'rbconfig'
require 'tempfile'

RSpec.describe 'apiserver-etcd-endpoints' do
  let(:script) { File.expand_path('../../files/kubernetes/apiserver-etcd-endpoints.rb', __dir__) }
  let(:servers) { ['https://172.22.4.9:2379', 'https://172.22.4.8:2379'] }
  let(:manifest) do
    { 'apiVersion' => 'v1', 'kind' => 'Pod', 'spec' => { 'containers' => [
      { 'name' => 'kube-apiserver', 'command' => ['kube-apiserver', "--etcd-servers=#{servers.join(',')}", '--unrelated-private=do-not-print'] },
    ] } }
  end
  let(:live) do
    Marshal.load(Marshal.dump(manifest)).merge(
      'metadata' => { 'name' => 'kube-apiserver-control1', 'namespace' => 'kube-system',
                      'uid' => 'b0424567-1234-1234-1234-123456789abc', 'annotations' => { 'kubernetes.io/config.mirror' => 'a' * 32 } },
      'spec' => Marshal.load(Marshal.dump(manifest.fetch('spec'))).merge('nodeName' => 'control1'),
      'status' => { 'phase' => 'Running', 'containerStatuses' => [
        { 'name' => 'kube-apiserver', 'ready' => true, 'state' => { 'running' => { 'startedAt' => '2026-10-24T00:00:00Z' } }, 'containerID' => "containerd://#{'b' * 64}" },
      ] },
    )
  end

  def observe(desired = manifest, pod = live)
    Tempfile.create('api-manifest') do |file|
      file.write(desired.is_a?(String) ? desired : YAML.dump(desired))
      file.flush
      Open3.capture3(RbConfig.ruby, script, 'control1', file.path, stdin_data: JSON.dump(pod))
    end
  end

  it 'projects only exact sorted endpoints and live runtime identities' do
    stdout, stderr, status = observe
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(JSON.parse(stdout)).to include('schema' => 1, 'endpoints' => servers.sort, 'observer' => 'control1', 'acceptance_recorded' => false)
    expect(stdout).not_to include('do-not-print', 'command', 'startedAt')
  end

  it 'supports endpoint flags in args and harmless endpoint reordering' do
    pod = live
    pod['spec']['containers'][0]['command'] = ['kube-apiserver']
    pod['spec']['containers'][0]['args'] = ["--etcd-servers=#{servers.reverse.join(',')}"]
    expect(observe(manifest, pod)[2]).to be_success
  end

  [
    ['mismatched configuration', ->(pod) { pod['spec']['containers'][0]['command'][1] = '--etcd-servers=https://other:2379' }],
    ['duplicate flags', ->(pod) { pod['spec']['containers'][0]['command'] << '--etcd-servers=https://other:2379' }],
    ['duplicate endpoints', ->(pod) { pod['spec']['containers'][0]['command'][1] = '--etcd-servers=https://other:2379,https://other:2379' }],
    ['insecure endpoint', ->(pod) { pod['spec']['containers'][0]['command'][1] = '--etcd-servers=http://other:2379' }],
    ['trailing empty endpoint', ->(pod) { pod['spec']['containers'][0]['command'][1] += ',' }],
    ['credentials in endpoint', ->(pod) { pod['spec']['containers'][0]['command'][1] = '--etcd-servers=https://do-not-print@other:2379' }],
    ['missing flag', ->(pod) { pod['spec']['containers'][0]['command'].delete_at(1) }],
    ['split flag', ->(pod) { pod['spec']['containers'][0]['command'][1] = '--etcd-servers' }],
    ['unexpected executable', ->(pod) { pod['spec']['containers'][0]['command'][0] = 'sh' }],
    ['wrong node', ->(pod) { pod['spec']['nodeName'] = 'control2' }],
    ['wrong namespace', ->(pod) { pod['metadata']['namespace'] = 'other' }],
    ['nonmirror Pod', ->(pod) { pod['metadata']['annotations'] = {} }],
    ['terminating Pod', ->(pod) { pod['metadata']['deletionTimestamp'] = '2026-10-24T00:00:00Z' }],
    ['unready container', ->(pod) { pod['status']['containerStatuses'][0]['ready'] = false }],
    ['waiting container', ->(pod) { pod['status']['containerStatuses'][0]['state'] = { 'waiting' => {} } }],
    ['missing bus-equivalent status', ->(pod) { pod.delete('status') }],
    ['missing runtime identity', ->(pod) { pod['status']['containerStatuses'][0].delete('containerID') }],
    ['extra container', ->(pod) { pod['spec']['containers'] << { 'name' => 'other' } }],
  ].each do |label, mutate|
    it "refuses #{label} without leaking input" do
      pod = live
      mutate.call(pod)
      stdout, stderr, status = observe(manifest, pod)
      expect(status).not_to be_success
      expect(stdout).to be_empty
      expect(stderr).to include('observation refused')
      expect(stderr).not_to include('do-not-print')
    end
  end

  it 'sanitizes YAML parser failures rather than printing private source lines' do
    stdout, stderr, status = observe("apiVersion: [do-not-print\n")
    expect(status).not_to be_success
    expect(stdout).to be_empty
    expect(stderr).not_to include('do-not-print')
  end
end
