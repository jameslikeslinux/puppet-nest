require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::kubernetes::reconcile_control_plane' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-etcd-reconcile-spec-') }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  it 'uses the public progress gate before any asset installation, lock or manifest mutation' do
    servers = ['https://172.22.4.8:2379', 'https://172.22.4.9:2379']
    allow_any_command.expect_call.be_called_times(1).return do |targets:, command:, **_options|
      expect(targets.map(&:name)).to eq(['localhost'])
      expect(command).to start_with('kubectl get ')
      expect(command).to include('readyz')
      Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_command(target, { 'stdout' => 'ok', 'stderr' => '', 'exit_code' => 0 }, 'command', command, []) })
    end
    expect_plan('nest::kubernetes::check_etcd').return do |params:, **_options|
      expect(params['target'].name).to eq('control1')
      expect(params['etcd_servers']).to eq(servers)
      expect(params['etcd_member_names']).to eq(['control1', 'control2', 'control3'])
      Bolt::PlanResult.new(Bolt::Error.new('No advancing quorum', 'nest/etcd-check'), 'failure')
    end

    result = run_plan('nest::kubernetes::reconcile_control_plane', 'targets' => 'control1', 'etcd_servers' => servers)

    expect(result.ok?).to be(false)
  end

  [false, true].each do |post_failure|
    it "reuses the same gate after mutation and rollback when post_failure=#{post_failure}" do
      descriptions = []
      allow_any_command.return do |targets:, command:, params:|
        description = params.fetch(:description)
        descriptions << description
        stdout = case description
                 when 'Determine whether reconciliation changed the static manifest' then 'false'
                 when 'Determine whether rollback requires static-Pod turnover' then 'same'
                 else 'fixture-value'
                 end
        Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_command(target, { 'stdout' => stdout, 'stderr' => '', 'exit_code' => 0 }, 'command', command, []) })
      end
      calls = 0
      expect_plan('nest::kubernetes::check_etcd').be_called_times(post_failure ? 3 : 2).return do |params:, **_options|
        expect(params['target'].name).to eq('control1')
        calls += 1
        if post_failure && calls == 2
          Bolt::PlanResult.new(Bolt::Error.new('No advancing quorum', 'nest/etcd-check'), 'failure')
        else
          Bolt::PlanResult.new({ 'kind' => 'nest_etcd_check', 'acceptance_recorded' => false }, 'success')
        end
      end

      result = run_plan('nest::kubernetes::reconcile_control_plane', 'targets' => 'control1', 'etcd_servers' => ['https://172.22.4.8:2379'])

      expect(result.ok?).to be(!post_failure)
      expect(descriptions).to include('Reconcile one control-plane manifest', 'Release cluster-wide control-plane reconciliation lock')
      expect(descriptions.include?('Restore kubeadm ConfigMap')).to be(post_failure)
    end
  end
end
