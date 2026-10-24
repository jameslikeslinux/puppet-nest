require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::kubernetes::check_apiserver_etcd' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-api-etcd-plan-spec-') }
  let(:servers) { ['https://172.22.4.8:2379', 'https://172.22.4.9:2379'] }
  let(:params) { { 'target' => 'control1', 'expected_servers' => servers } }
  let(:api) do
    { 'schema' => 1, 'kind' => 'nest_apiserver_etcd_endpoints', 'observer' => 'control1', 'endpoints' => servers,
      'pod_uid' => 'b0424567-1234-1234-1234-123456789abc', 'mirror' => 'a' * 32,
      'container_id' => "containerd://#{'b' * 64}", 'acceptance_recorded' => false }
  end
  let(:quorum) { { 'kind' => 'nest_etcd_check', 'acceptance_recorded' => false, 'reboot_eligible' => [] } }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  it 'binds native quorum sampling to configured observed API endpoints and unchanged runtime identity' do
    allow_any_command.expect_call.with_targets('control1').be_called_times(2).return do |targets:, command:, **_options|
      expect(command).to include('timeout --signal=TERM --kill-after=2s 15s', '--request-timeout=10s',
                                 'get pod kube-apiserver-control1 -o json', '/etc/kubernetes/manifests/kube-apiserver.yaml')
      expect(command).not_to include('reconcile_control_plane', 'kubeadm init', 'emerge ', 'reboot', 'curl -k')
      Bolt::ResultSet.new(targets.map do |target|
        Bolt::Result.for_command(target, { 'stdout' => JSON.dump(api), 'stderr' => '', 'exit_code' => 0 }, 'command', command, [])
      end)
    end
    expect_plan('nest::kubernetes::check_etcd').with_params('target' => 'control1', 'etcd_servers' => servers,
                                                         'etcd_member_names' => ['control1', 'control2', 'control3'], 'sample_seconds' => 2, 'max_lag' => 1000).always_return(quorum)

    result = run_plan('nest::kubernetes::check_apiserver_etcd', params)

    expect(result.ok?).to be(true)
    expect(result.value).to include('api' => api, 'etcd' => quorum, 'reboot_eligible' => [], 'acceptance_recorded' => false)
  end

  it 'can discover the actual configured list without a guessed seed policy' do
    allow_any_command.expect_call.be_called_times(2).always_return('stdout' => JSON.dump(api))
    expect_plan('nest::kubernetes::check_etcd').always_return(quorum)

    expect(run_plan('nest::kubernetes::check_apiserver_etcd', 'target' => 'control1').ok?).to be(true)
  end

  it 'refuses policy mismatch before quorum sampling' do
    allow_any_command.expect_call.be_called_times(1).always_return('stdout' => JSON.dump(api))

    expect(run_plan('nest::kubernetes::check_apiserver_etcd', params.merge('expected_servers' => [servers[0]])).ok?).to be(false)
  end

  it 'propagates acquisition failure without sampling or retry' do
    allow_any_command.expect_call.be_called_times(1).error_with('kind' => 'bolt/run-failure', 'msg' => 'API unavailable')

    expect(run_plan('nest::kubernetes::check_apiserver_etcd', params).ok?).to be(false)
  end

  it 'refuses a changed API runtime after sampling' do
    count = 0
    allow_any_command.expect_call.be_called_times(2).return do |targets:, command:, **_options|
      count += 1
      observed = (count == 1) ? api : api.merge('container_id' => "containerd://#{'c' * 64}")
      Bolt::ResultSet.new(targets.map do |target|
        Bolt::Result.for_command(target, { 'stdout' => JSON.dump(observed), 'stderr' => '', 'exit_code' => 0 }, 'command', command, [])
      end)
    end
    expect_plan('nest::kubernetes::check_etcd').always_return(quorum)

    expect(run_plan('nest::kubernetes::check_apiserver_etcd', params).ok?).to be(false)
  end

  [
    { 'target' => ['control1', 'control2'] },
    { 'target' => 'other' },
    { 'expected_servers' => [] },
    { 'expected_servers' => ['http://other:2379'] },
    { 'expected_servers' => ['https://other:2379'] * 2 },
    { 'etcd_member_names' => ['control1', 'control1', 'control3'] },
    { 'etcd_member_names' => ['control1', 'control2'] },
  ].each do |change|
    it "refuses invalid inputs #{change} before host commands" do
      allow_any_command.not_be_called

      expect(run_plan('nest::kubernetes::check_apiserver_etcd', params.merge(change)).ok?).to be(false)
    end
  end
end
