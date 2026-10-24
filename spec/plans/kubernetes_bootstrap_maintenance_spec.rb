require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'control-plane bootstrap maintenance boundary' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-bootstrap-maintenance-spec-') }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  it 'rejects omitted excluded-advertiser maintenance inputs before any initialization command' do
    allow_any_command.not_be_called
    expect_plan('nest::kubernetes::generate_kube_vip_manifest').not_be_called
    result = run_plan('nest::kubernetes::init', 'targets' => ['control1', 'control2', 'control3'], 'name' => 'fixture',
                                              'control_plane_endpoint' => 'fixture.invalid', 'vip' => '172.21.255.255', 'vip_advertisers' => ['control1', 'control2'])
    expect(result.ok?).to be(false)
  end

  it 'requires bootstrap maintenance input before the first umbrella step' do
    allow_any_command.not_be_called
    expect_plan('nest::kubernetes::pull_images').not_be_called
    expect_plan('nest::kubernetes::init').not_be_called
    expect(run_plan('nest::eyrie::build', {}).ok?).to be(false)
  end

  it 'forwards reviewed maintenance fields through the native YAML umbrella without guessing topology' do
    input = { 'client' => 'fixture-client', 'advertisers' => {}, 'physical_domains' => {}, 'ceph_fsid' => nil }
    expect_plan('nest::kubernetes::pull_images')
    expected = { 'targets' => 'eyrie-control-plane', 'name' => 'eyrie', 'control_plane_endpoint' => 'control-plane.eyrie',
                 'vip' => '172.21.255.255', 'vip_advertisers' => ['control1', 'control2'],
                 'etcd_servers' => ['https://172.22.4.9:2379', 'https://172.22.4.8:2379'], 'vip_maintenance' => input }
    expect_plan('nest::kubernetes::init').with_params(expected).error_with('kind' => 'nest/fixture', 'msg' => 'stop before any mutation')
    allow_any_command.not_be_called
    expect(run_plan('nest::eyrie::build', 'vip_maintenance' => input).ok?).to be(false)
  end
end
