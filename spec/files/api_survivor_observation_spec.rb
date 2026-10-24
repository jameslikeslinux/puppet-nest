# frozen_string_literal: true

require 'json'
require 'yaml'
require 'open3'
require 'rbconfig'
require 'tempfile'

RSpec.describe 'api-survivor-observation' do
  let(:script) { File.expand_path('../../files/kubernetes/api-survivor-observation.rb', __dir__) }
  let(:ca) { '/etc/kubernetes/pki/ca.crt' }
  let(:route) do
    { 'dst' => '172.21.255.255', 'protocol' => 'bird', 'flags' => [], 'nexthops' => [
      { 'gateway' => '172.22.4.7', 'dev' => 'br0', 'weight' => 1, 'flags' => [] },
      { 'gateway' => '172.22.4.8', 'dev' => 'br0', 'weight' => 1, 'flags' => [] },
    ] }
  end
  let(:lookup) { { 'dst' => '172.21.255.255', 'gateway' => '172.22.4.8', 'dev' => 'br0', 'table' => 'bird', 'flags' => [], 'uid' => 0, 'cache' => [] } }
  let(:native) { { 'routes' => [route], 'lookup' => [lookup] } }
  let(:manifest) do
    env = { 'cp_enable' => 'true', 'bgp_enable' => 'true', 'address' => '172.21.255.255', 'port' => '6443', 'bgp_routerid' => '172.22.4.7',
            'control_plane_health_check_address' => 'https://control1:6443/readyz', 'control_plane_health_check_ca_path' => ca,
            'unrelated' => 'PRIVATE_DO_NOT_PRINT' }
    { 'apiVersion' => 'v1', 'kind' => 'Pod', 'spec' => { 'hostNetwork' => true, 'containers' => [
      { 'name' => 'kube-vip', 'image' => 'ghcr.io/kube-vip/kube-vip:v1.2.4', 'env' => env.map { |name, value| { 'name' => name, 'value' => value } },
        'volumeMounts' => [{ 'name' => 'health-check-ca', 'mountPath' => ca, 'readOnly' => true }] },
    ], 'volumes' => [{ 'name' => 'health-check-ca', 'hostPath' => { 'path' => ca, 'type' => 'File' } }] } }
  end
  let(:live) do
    Marshal.load(Marshal.dump(manifest)).merge(
      'metadata' => { 'name' => 'kube-vip-control1', 'namespace' => 'kube-system', 'uid' => 'b0424567-1234-1234-1234-123456789abc',
                      'annotations' => { 'kubernetes.io/config.mirror' => 'a' * 32 } },
      'spec' => Marshal.load(Marshal.dump(manifest['spec'])).merge('nodeName' => 'control1'),
      'status' => { 'phase' => 'Running', 'containerStatuses' => [
        { 'name' => 'kube-vip', 'ready' => true, 'state' => { 'running' => {} }, 'containerID' => "cri-o://#{'b' * 64}" },
      ] },
    )
  end

  def observe_route(data = native)
    Open3.capture3(RbConfig.ruby, script, 'route', '172.21.255.255', '172.22.4.7', '172.22.4.7,172.22.4.8', stdin_data: JSON.dump(data))
  end

  def observe_vip(pod = live, desired = manifest)
    Tempfile.create('survivor-manifest') do |file|
      file.write(desired.is_a?(String) ? desired : YAML.dump(desired))
      file.flush
      Open3.capture3(RbConfig.ruby, script, 'vip', 'control1', '172.21.255.255', '172.22.4.7', file.path, stdin_data: JSON.dump(pod))
    end
  end

  it 'uses actual kernel table and lookup, not a healthy RIB claim' do
    stdout, stderr, status = observe_route
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(JSON.parse(stdout)).to include('kind' => 'nest_api_survivor_route', 'table' => 100, 'acceptance_recorded' => false)
    expect(stdout).not_to include('uid', 'cache')
  end

  it 'normalizes row order, numeric table and ECMP selected path differences' do
    before = observe_route[0]
    data = native
    data['routes'][0]['nexthops'].reverse!
    data['lookup'][0]['gateway'] = '172.22.4.7'
    data['lookup'][0]['table'] = 100
    expect(observe_route(data)[0]).to eq(before)
  end

  it 'supports one surviving kernel next hop' do
    data = native
    data['routes'][0] = { 'dst' => '172.21.255.255/32', 'protocol' => 'bird', 'gateway' => '172.22.4.7', 'dev' => 'br0' }
    data['lookup'][0]['gateway'] = '172.22.4.7'
    expect(observe_route(data)[2]).to be_success
  end

  [
    ['absent kernel route despite live BIRD RIB', ->(data) { data['routes'] = [] }],
    ['wrong destination', ->(data) { data['routes'][0]['dst'] = 'default' }],
    ['non BIRD route', ->(data) { data['routes'][0]['protocol'] = 'static' }],
    ['blackhole', ->(data) { data['routes'][0]['type'] = 'blackhole' }],
    ['dead route', ->(data) { data['routes'][0]['flags'] = ['linkdown'] }],
    ['dead next hop', ->(data) { data['routes'][0]['nexthops'][0]['flags'] = ['dead'] }],
    ['survivor absent', ->(data) { data['routes'][0]['nexthops'].shift }],
    ['unexpected next hop', ->(data) { data['routes'][0]['nexthops'][1]['gateway'] = '172.22.4.9' }],
    ['duplicate next hop', ->(data) { data['routes'][0]['nexthops'] << data['routes'][0]['nexthops'][0] }],
    ['missing lookup', ->(data) { data['lookup'] = [] }],
    ['wrong lookup table', ->(data) { data['lookup'][0]['table'] = 'main' }],
    ['lookup bypassing route', ->(data) { data['lookup'][0]['gateway'] = '172.22.4.1' }],
    ['wrong lookup device', ->(data) { data['lookup'][0]['dev'] = 'podman1' }],
    ['malformed next hops', ->(data) { data['routes'][0]['nexthops'] = nil }],
    ['missing next-hop identity', ->(data) { data['routes'][0]['nexthops'][0].delete('gateway') }],
  ].each do |label, mutate|
    it "refuses #{label}" do
      data = native
      mutate.call(data)
      stdout, stderr, status = observe_route(data)
      expect(status).not_to be_success
      expect(stdout).to be_empty
      expect(stderr).to include('observation refused')
    end
  end

  it 'binds ready VIP runtime to matching static strict health and CA policy' do
    stdout, stderr, status = observe_vip
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(JSON.parse(stdout)).to include('kind' => 'nest_api_survivor_vip', 'survivor' => 'control1', 'acceptance_recorded' => false)
    expect(stdout).not_to include('PRIVATE_DO_NOT_PRINT', 'env', 'volumeMounts')
  end

  [
    ['wrong host', ->(pod) { pod['spec']['nodeName'] = 'control2' }],
    ['terminating Pod', ->(pod) { pod['metadata']['deletionTimestamp'] = 'now' }],
    ['non mirror Pod', ->(pod) { pod['metadata']['annotations'] = {} }],
    ['unready VIP', ->(pod) { pod['status']['containerStatuses'][0]['ready'] = false }],
    ['missing status', ->(pod) { pod.delete('status') }],
    ['missing runtime', ->(pod) { pod['status']['containerStatuses'][0].delete('containerID') }],
    ['stopped runtime', ->(pod) { pod['status']['containerStatuses'][0]['state'] = { 'terminated' => {} } }],
    ['wrong image', ->(pod) { pod['spec']['containers'][0]['image'] = 'other:v1' }],
    ['nonhost network', ->(pod) { pod['spec']['hostNetwork'] = false }],
    ['duplicate environment', ->(pod) { pod['spec']['containers'][0]['env'] << pod['spec']['containers'][0]['env'][0] }],
    ['disabled BGP', ->(pod) { pod['spec']['containers'][0]['env'].find { |item| item['name'] == 'bgp_enable' }['value'] = 'false' }],
    ['unverified health', ->(pod) { pod['spec']['containers'][0]['env'].find { |item| item['name'] == 'control_plane_health_check_ca_path' }['value'] = '' }],
    ['writable CA', ->(pod) { pod['spec']['containers'][0]['volumeMounts'][0]['readOnly'] = false }],
    ['wrong CA source', ->(pod) { pod['spec']['volumes'][0]['hostPath']['path'] = '/other' }],
  ].each do |label, mutate|
    it "refuses #{label} without leaking Pod configuration" do
      pod = live
      mutate.call(pod)
      stdout, stderr, status = observe_vip(pod)
      expect(status).not_to be_success
      expect(stdout).to be_empty
      expect(stderr).to include('observation refused')
      expect(stderr).not_to include('PRIVATE_DO_NOT_PRINT')
    end
  end

  it 'sanitizes malformed YAML errors' do
    stdout, stderr, status = observe_vip(live, 'value: [PRIVATE_DO_NOT_PRINT')
    expect(status).not_to be_success
    expect(stdout).to be_empty
    expect(stderr).not_to include('PRIVATE_DO_NOT_PRINT')
  end
end
