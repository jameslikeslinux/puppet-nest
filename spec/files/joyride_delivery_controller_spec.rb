require 'open3'
require 'spec_helper'
require 'yaml'

RSpec.describe 'Joyride trusted TEST delivery adapter' do
  let(:repo_root) { File.expand_path('../..', __dir__) }
  let(:resources) { YAML.safe_load_file(File.join(repo_root, 'data/kubernetes/app/joyride.yaml'), aliases: true).fetch('resources') }

  it 'preserves interruption recovery, exact image identity and fail-closed state transitions' do
    test_path = File.join(repo_root, 'spec/app/joyride/test_delivery_controller.py')
    stdout, stderr, status = Open3.capture3({ 'PYTHONDONTWRITEBYTECODE' => '1' }, 'python3', test_path)

    expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
  end

  it 'verifies duplicate artifact provenance without replacing the original receipt' do
    test_path = File.join(repo_root, 'spec/app/joyride/test_import_artifacts.py')
    stdout, stderr, status = Open3.capture3({ 'PYTHONDONTWRITEBYTECODE' => '1' }, 'python3', test_path)

    expect(status.success?).to be(true), "#{stdout}\n#{stderr}"
  end

  it 'limits Kubernetes authority to the TEST workload and its nonsecret journal' do
    rules = resources.fetch('delivery_role').fetch('rules')
    expect(rules.length).to eq(2)
    expect(rules[0]).to eq({ 'apiGroups' => ['apps'], 'resources' => ['deployments'], 'resourceNames' => ['joyride-test'], 'verbs' => ['get', 'patch'] })
    expect(rules[1]).to eq({ 'apiGroups' => [''], 'resources' => ['configmaps'], 'resourceNames' => ['joyride-test-delivery-journal'], 'verbs' => ['get', 'update'] })
    expect(resources.fetch('delivery_role').dig('metadata', 'namespace')).to eq('test')
    expect(resources.fetch('delivery_journal')).not_to have_key('data')
  end

  it 'keeps controller code and credentials separate from candidate application artifacts' do
    cronjob = resources.fetch('delivery_controller').fetch('spec')
    pod = cronjob.dig('jobTemplate', 'spec', 'template', 'spec')
    controller = pod.fetch('containers').first
    credential = pod.fetch('volumes').find { |volume| volume.fetch('name') == 'credential' }

    expect(cronjob.fetch('concurrencyPolicy')).to eq('Forbid')
    expect(controller.fetch('image')).to match(%r{\Aregistry\.gitlab\.joyfullee\.me/joy/joyride/app@sha256:[0-9a-f]{64}\z})
    expect(controller.fetch('command')).to eq(['python', '/platform/test_delivery_controller.py'])
    expect(controller).not_to have_key('envFrom')
    expect(credential.fetch('secret')).to eq({ 'secretName' => 'joyride-test-runtime', 'items' => [{ 'key' => 'DELIVERY_TOKEN', 'path' => 'DELIVERY_TOKEN' }] })
    expect(pod).not_to have_key('nodeSelector')
    expect(pod).not_to have_key('affinity')
    expect(pod).not_to have_key('tolerations')
  end
end
