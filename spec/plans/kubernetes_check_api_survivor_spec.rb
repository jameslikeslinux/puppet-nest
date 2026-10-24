require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::kubernetes::check_api_survivor' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-api-survivor-plan-spec-') }
  let(:params) do
    { 'target' => 'control2', 'survivor' => 'control1', 'client' => 'owl', 'advertisers' => { 'control1' => '172.22.4.7', 'control2' => '172.22.4.8' } }
  end
  let(:vip) { { 'kind' => 'nest_api_survivor_vip', 'container_id' => 'original' } }
  let(:route) { { 'kind' => 'nest_api_survivor_route', 'next_hops' => ['172.22.4.7', '172.22.4.8'] } }
  let(:backend) { { 'kind' => 'nest_apiserver_etcd_check', 'reboot_eligible' => [], 'acceptance_recorded' => false } }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  def observations(change = nil)
    counts = Hash.new(0)
    allow_any_command.expect_call.be_called_times((change == :tls_failure) ? 3 : 6).return do |targets:, command:, **_options|
      expect(command).not_to include('curl -k', 'reboot', 'systemctl restart', 'birdc', 'kubeadm init', 'rsync ')
      value = if command.include?('get pod kube-vip-')
                expect(targets.map(&:name)).to eq(['control1'])
                expect(command).to include('timeout --signal=TERM --kill-after=2s 15s', '--request-timeout=10s')
                counts[:vip] += 1
                (change == :vip && counts[:vip] == 2) ? vip.merge('container_id' => 'changed') : vip
              elsif command.include?('route show table 100')
                expect(targets.map(&:name)).to eq(['owl'])
                expect(command).to include('ip -j -4 route get 172.21.255.255')
                counts[:route] += 1
                (change == :route && counts[:route] == 2) ? route.merge('next_hops' => ['172.22.4.8']) : route
              else
                expect(targets.map(&:name)).to eq(['owl'])
                expect(command).to include('curl -q --fail', '--noproxy', '--cacert /etc/kubernetes/pki/ca.crt', '--max-time 5',
                                           'control-plane.eyrie:6443:172.22.4.7', 'control-plane.eyrie:6443:172.21.255.255')
                {}
              end
      Bolt::ResultSet.new(targets.map do |target|
        Bolt::Result.for_command(target, { 'stdout' => JSON.dump(value), 'stderr' => '', 'exit_code' => (change == :tls_failure && command.start_with?('curl')) ? 60 : 0 },
                                'command', command, [])
      end)
    end
  end

  it 'requires stable ready VIP runtime, actual client kernel path, strict direct and VIP TLS and bound quorum' do
    observations
    expect_plan('nest::kubernetes::check_apiserver_etcd').with_params('target' => 'control1', 'expected_servers' => nil, 'sample_seconds' => 2, 'max_lag' => 1000).always_return(backend)

    result = run_plan('nest::kubernetes::check_api_survivor', params)

    expect(result.ok?).to be(true)
    expect(result.value).to include('vip' => vip, 'route' => route, 'backend' => backend, 'client' => 'owl', 'target' => 'control2',
                                    'reboot_eligible' => [], 'acceptance_recorded' => false)
  end

  [:vip, :route].each do |change|
    it "refuses changed #{change} identity without mutation or retry" do
      observations(change)
      expect_plan('nest::kubernetes::check_apiserver_etcd').always_return(backend)

      expect(run_plan('nest::kubernetes::check_api_survivor', params).ok?).to be(false)
    end
  end

  it 'halts on TLS failure before quorum acquisition' do
    observations(:tls_failure)

    expect(run_plan('nest::kubernetes::check_api_survivor', params).ok?).to be(false)
  end

  it 'propagates backend failure before postchecks without retry' do
    allow_any_command.expect_call.be_called_times(3).always_return('stdout' => JSON.dump(vip))
    expect_plan('nest::kubernetes::check_apiserver_etcd').error_with('kind' => 'nest/quorum', 'msg' => 'not advancing')

    expect(run_plan('nest::kubernetes::check_api_survivor', params).ok?).to be(false)
  end

  [
    { 'target' => ['control1', 'control2'] },
    { 'survivor' => 'control2' },
    { 'survivor' => 'other' },
    { 'client' => 'control1' },
    { 'client' => ['owl', 'eagle'] },
    { 'advertisers' => { 'control2' => '172.22.4.8' } },
    { 'advertisers' => { 'control1' => '172.22.4.7', 'control2' => '172.22.4.7' } },
    { 'advertisers' => { 'control1' => '172.22.4.7', 'unknown' => '172.22.4.8' } },
    { 'server_name' => 'bad;name' },
    { 'expected_servers' => [] },
    { 'expected_servers' => ['http://other:2379'] },
  ].each do |change|
    it "refuses invalid scope #{change} before host commands" do
      allow_any_command.not_be_called

      expect(run_plan('nest::kubernetes::check_api_survivor', params.merge(change)).ok?).to be(false)
    end
  end
end
