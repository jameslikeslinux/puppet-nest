require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::kubernetes::check_etcd' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-etcd-plan-spec-') }
  let(:servers) { ['https://172.22.4.7:2379', 'https://172.22.4.8:2379', 'https://172.22.4.9:2379'] }
  let(:params) { { 'target' => 'control1', 'etcd_servers' => servers } }
  let(:quorum) { { 'schema' => 1, 'kind' => 'nest_etcd_quorum_observation', 'result' => 'pass', 'advancing' => true, 'acceptance_recorded' => false } }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  it 'uses a single bounded native command with two health/status/membership samples and module-owned validation' do
    allow_any_command.expect_call.with_targets('control1').return do |targets:, command:, **_options|
      expect(command.scan('endpoint health --cluster').length).to eq(2)
      expect(command.scan('endpoint status --cluster').length).to eq(2)
      expect(command.scan('member list --write-out=json').length).to eq(2)
      expect(command).to include('timeout --signal=TERM --kill-after=2s 15s', '--request-timeout=10s', '--dial-timeout=3s', '--command-timeout=5s')
      expect(command).to include('sleep 2', '--previous-status', '--previous-members')
      expect(command).not_to include('/usr/local/sbin/validate-etcd-cluster', 'defrag', 'snapshot save', 'endpoint hashkv', 'kubeadm init', 'emerge ', 'reboot')
      Bolt::ResultSet.new(targets.map do |target|
        Bolt::Result.for_command(target, { 'stdout' => JSON.dump(quorum), 'stderr' => '', 'exit_code' => 0 }, 'command', command, [])
      end)
    end

    result = run_plan('nest::kubernetes::check_etcd', params)

    expect(result.ok?).to be(true)
    expect(result.value).to include('kind' => 'nest_etcd_check', 'quorum' => quorum, 'sample_seconds' => 2,
                                   'observer' => 'control1', 'endpoints' => servers, 'reboot_eligible' => [], 'acceptance_recorded' => false)
  end

  it 'preserves a subset of seed endpoints while requiring complete discovered voting membership' do
    allow_any_command.expect_call.with_targets('control1').always_return('stdout' => JSON.dump(quorum))

    expect(run_plan('nest::kubernetes::check_etcd', params.merge('etcd_servers' => servers.drop(1))).ok?).to be(true)
  end

  it 'propagates unavailable, unhealthy or nonadvancing native results without a second attempt' do
    allow_any_command.expect_call.be_called_times(1).error_with('kind' => 'bolt/run-failure', 'msg' => 'Etcd guard refused')

    expect(run_plan('nest::kubernetes::check_etcd', params).ok?).to be(false)
  end

  it 'refuses a single snapshot result even if the native process exits zero' do
    allow_any_command.expect_call.always_return('stdout' => JSON.dump(quorum.merge('advancing' => false)))

    expect(run_plan('nest::kubernetes::check_etcd', params).ok?).to be(false)
  end

  [
    { 'target' => ['control1', 'control2'] },
    { 'target' => 'other' },
    { 'etcd_member_names' => ['control1', 'control1', 'control3'] },
    { 'etcd_member_names' => ['control1', 'control2'] },
    { 'etcd_servers' => [] },
    { 'etcd_servers' => ['http://172.22.4.7:2379'] },
    { 'etcd_servers' => ['https://172.22.4.7:2379;reboot'] },
    { 'etcd_servers' => ['https://172.22.4.7:2379'] * 2 },
    { 'sample_seconds' => 0 },
    { 'sample_seconds' => 6 },
    { 'max_lag' => -1 },
  ].each do |change|
    it "refuses invalid complete observation inputs #{change} before host commands" do
      allow_any_command.not_be_called

      expect(run_plan('nest::kubernetes::check_etcd', params.merge(change)).ok?).to be(false)
    end
  end
end
