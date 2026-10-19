# frozen_string_literal: true

require 'open3'
require 'rbconfig'
require 'yaml'

RSpec.describe 'kube-vip health CA manifest integration' do
  let(:script) { File.expand_path('../../files/kubernetes/kube-vip-health-ca.rb', __dir__) }
  let(:manifest) do
    {
      'spec' => {
        'containers' => [{
          'name' => 'kube-vip',
          'env' => [
            { 'name' => 'control_plane_health_check_address', 'value' => 'https://control1:6443/readyz' },
            { 'name' => 'control_plane_health_check_ca_path', 'value' => '/etc/kubernetes/pki/ca.crt' },
            { 'name' => 'prometheus_server', 'value' => ':2112' },
          ],
          'volumeMounts' => [{ 'name' => 'kubeconfig', 'mountPath' => '/etc/kubernetes/admin.conf' }],
        }],
        'volumes' => [{ 'name' => 'kubeconfig', 'hostPath' => { 'path' => '/etc/kubernetes/admin.conf' } }],
      },
    }
  end

  it 'mounts only the public CA read-only and preserves existing kubeconfig mounts' do
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, stdin_data: YAML.dump(manifest))
    expect(status).to be_success, stderr
    spec = YAML.safe_load(stdout).fetch('spec')
    expect(spec.fetch('containers').first.fetch('volumeMounts')).to include(
      { 'name' => 'health-check-ca', 'mountPath' => '/etc/kubernetes/pki/ca.crt', 'readOnly' => true },
      { 'name' => 'kubeconfig', 'mountPath' => '/etc/kubernetes/admin.conf' },
    )
    expect(spec.fetch('volumes')).to include(
      { 'name' => 'health-check-ca', 'hostPath' => { 'path' => '/etc/kubernetes/pki/ca.crt', 'type' => 'File' } },
    )
  end

  it 'preserves the leading colon of Go plain YAML listen addresses without Ruby tags' do
    input = YAML.dump(manifest).sub(%r{value: ['"]:2112['"]}, 'value: :2112')
    expect(input).to include('value: :2112')
    stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, stdin_data: input)
    expect(status).to be_success, stderr
    env = YAML.safe_load(stdout).dig('spec', 'containers', 0, 'env')
    expect(env.find { |item| item['name'] == 'prometheus_server' }.fetch('value')).to eq(':2112')
    expect(stdout).not_to include('!ruby')
  end

  it 'refuses liveness-only advertising qualification' do
    manifest['spec']['containers'].first['env'].first['value'] = 'https://control1:6443/livez'
    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, stdin_data: YAML.dump(manifest))
    expect(status).not_to be_success
    expect(stderr).to include('strict readiness')
  end
end
