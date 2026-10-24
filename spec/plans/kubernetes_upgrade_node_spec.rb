require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::kubernetes::upgrade_node maintenance boundary' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-upgrade-maintenance-spec-') }
  let(:maintenance) { { 'survivor' => 'control1', 'client' => 'owl', 'advertisers' => {}, 'physical_domains' => {}, 'ceph_fsid' => nil } }
  let(:params) { { 'targets' => 'control3', 'etcd_servers' => ['https://172.22.4.8:2379'], 'maintenance' => { 'control3' => maintenance }, 'sync' => false, 'upgrade_kubelet' => false } }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  it 'rejects missing controller maintenance inputs after read-only classification but before any package or repository change' do
    allow_any_command.expect_call.be_called_times(1).always_return('stdout' => 'true')
    expect_plan('nest::kubernetes::reconcile_control_plane').not_be_called
    expect(run_plan('nest::kubernetes::upgrade_node', params.reject { |key, _value| key == 'maintenance' }).ok?).to be(false)
  end

  it 'propagates maintenance failure before package or repository mutation' do
    allow_any_command.expect_call.be_called_times(1).always_return('stdout' => 'true')
    expect_plan('nest::kubernetes::check_control_plane_maintenance').with_params(maintenance.merge('target' => 'control3')).error_with('kind' => 'nest/maintenance', 'msg' => 'unsafe')
    expect_plan('nest::kubernetes::reconcile_control_plane').not_be_called
    expect(run_plan('nest::kubernetes::upgrade_node', params).ok?).to be(false)
  end

  it 'forwards the exact admitted member inputs into strict reconciliation rather than losing the gate at the wrapper boundary' do
    admitted = false
    allow_any_command.expect_call.be_called_times(3).return do |targets:, command:, **_options|
      classification = command.start_with?('if test -f')
      expect(admitted).to be(true) unless classification
      expect(command).not_to include('systemctl restart', 'renew')
      Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_command(target, { 'stdout' => classification ? 'true' : '', 'stderr' => '', 'exit_code' => 0 }, 'command', command, []) })
    end
    expect_plan('nest::kubernetes::check_control_plane_maintenance').return do |**_options|
      admitted = true
      Bolt::PlanResult.new({}, 'success')
    end
    expect_plan('nest::kubernetes::reconcile_control_plane').return do |params:, **_options|
      expect(params['targets'].name).to eq('control3')
      expect(params['maintenance']).to eq(maintenance)
      expect(params['upgrade_components']).to be(true)
      Bolt::PlanResult.new({}, 'success')
    end
    expect(run_plan('nest::kubernetes::upgrade_node', params).ok?).to be(true)
  end

  it 'preserves worker-only upgrades without requiring controller admission' do
    allow_any_command.expect_call.be_called_times(3).always_return('stdout' => 'false')
    expect_plan('nest::kubernetes::check_control_plane_maintenance').not_be_called
    expect_plan('nest::kubernetes::reconcile_control_plane').not_be_called
    expect(run_plan('nest::kubernetes::upgrade_node', 'targets' => 'fixture-worker', 'sync' => false, 'upgrade_kubelet' => false).ok?).to be(true)
  end
end
