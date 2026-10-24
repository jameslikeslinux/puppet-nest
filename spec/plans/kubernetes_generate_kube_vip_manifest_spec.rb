require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::kubernetes::generate_kube_vip_manifest' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-vip-maintenance-spec-') }
  let(:maintenance) { { 'client' => 'owl', 'advertisers' => {}, 'physical_domains' => {}, 'ceph_fsid' => 'fixture' } }
  let(:params) { { 'targets' => 'control3', 'vip' => '172.21.255.255', 'survivor' => 'control1', 'maintenance' => maintenance } }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  [false, true].each do |advertise|
    it "fails admission before VIP mutation when advertise=#{advertise}" do
      allow_any_command.expect_call.be_called_times(1).always_return('stdout' => 'present')
      expected = maintenance.merge('target' => 'control3', 'survivor' => 'control1', 'vip' => '172.21.255.255')
      expect_plan('nest::kubernetes::check_control_plane_maintenance').with_params(expected).error_with('kind' => 'nest/maintenance', 'msg' => 'unsafe')
      expect(run_plan('nest::kubernetes::generate_kube_vip_manifest', params.merge('advertise' => advertise)).ok?).to be(false)
    end

    it "admits the exact single member before VIP mutation when advertise=#{advertise}" do
      admitted = false
      allow_any_command.expect_call.be_called_times(2).return do |targets:, command:, **_options|
        classification = command.start_with?('if test -s')
        expect(admitted).to be(true) unless classification
        expect(command).not_to include('birdc')
        expect(targets.map(&:name)).to eq(['control3'])
        Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_command(target, { 'stdout' => classification ? 'present' : '', 'stderr' => '', 'exit_code' => 0 }, 'command', command, []) })
      end
      expect_plan('nest::kubernetes::check_control_plane_maintenance').return do |**_options|
        admitted = true
        Bolt::PlanResult.new({ 'kind' => 'nest_control_plane_maintenance_check' }, 'success')
      end
      expect(run_plan('nest::kubernetes::generate_kube_vip_manifest', params.merge('advertise' => advertise)).ok?).to be(true)
    end
  end

  it 'refuses missing full maintenance inputs rather than falling back to target RIB or direct survivor curl' do
    allow_any_command.expect_call.be_called_times(1).always_return('stdout' => 'present')
    expect_plan('nest::kubernetes::check_control_plane_maintenance').not_be_called
    expect(run_plan('nest::kubernetes::generate_kube_vip_manifest', params.reject { |key, _value| key == 'maintenance' }).ok?).to be(false)
  end

  it 'retains fresh manifest creation without an existing live advertiser or maintenance policy' do
    allow_any_command.expect_call.be_called_times(2).always_return('stdout' => 'absent')
    expect_plan('nest::kubernetes::check_control_plane_maintenance').not_be_called
    expect(run_plan('nest::kubernetes::generate_kube_vip_manifest', 'targets' => 'control3', 'vip' => '172.21.255.255').ok?).to be(true)
  end
end
