require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::app::hermes::retain_generation' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-generation-hold-spec-') }
  let(:params) do
    { 'target' => 'owl', 'action' => 'hold', 'hold_id' => 'release-fixture', 'release' => "sha256:#{'a' * 64}",
      'checkpoint' => 'fixture', 'expected_sha256' => 'b' * 64, 'max_age_seconds' => 3600 }
  end

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  ['hold', 'check-hold', 'release-hold'].each do |action|
    it "runs exact #{action} once without initializing storage, capture or pruning" do
      expect_command('mktemp /tmp/nest-hermes-backup-generation.XXXXXXXX').with_targets('owl').always_return('stdout' => "/fixture/helper\n")
      expect_upload('nest/hermes-backup-generation').with_targets('owl').with_destination('/fixture/helper')
      allow_any_command.return do |targets:, command:, **_options|
        expect(command).to include("/fixture/helper #{action} --backup-dir /nest/backup/hermes --checkpoint fixture")
        expect(command).to include("--expected-sha256 #{'b' * 64} --hold-id release-fixture --release sha256:#{'a' * 64}")
        if action == 'release-hold'
          expect(command).not_to include('--max-age-seconds')
        else
          expect(command).to include('--max-age-seconds 3600')
        end
        expect(command).to include('runuser -u joy -- podman unshare')
        expect(command).not_to include('install -d', '--hermes-bin', '--stage-dir', '--retain', '--no-prune')
        Bolt::ResultSet.new(targets.map do |target|
          Bolt::Result.for_command(target, { 'stdout' => '{"readback_verified":true}', 'stderr' => '', 'exit_code' => 0 }, 'command', command, [])
        end)
      end
      inputs = params.merge('action' => action)
      inputs.delete('max_age_seconds') if action == 'release-hold'
      result = run_plan('nest::app::hermes::retain_generation', inputs)
      expect(result.ok?).to be(true)
      expect(result.value.first.value['stdout']).to eq('{"readback_verified":true}')
    end
  end

  ['hold_id', 'release', 'checkpoint', 'expected_sha256', 'max_age_seconds'].each do |key|
    it "requires exact #{key} before any host command" do
      allow_any_command.not_be_called
      expect(run_plan('nest::app::hermes::retain_generation', params.reject { |field, _value| field == key }).ok?).to be(false)
    end
  end

  it 'rejects multi-target and duplicate profiles before remote allocation' do
    allow_any_command.not_be_called
    expect(run_plan('nest::app::hermes::retain_generation', params.merge('target' => ['owl', 'fixture-other'])).ok?).to be(false)
    expect(run_plan('nest::app::hermes::retain_generation', params.merge('required_profiles' => ['talon', 'talon'])).ok?).to be(false)
  end

  it 'propagates native refusal without retry or capture fallback' do
    expect_command('mktemp /tmp/nest-hermes-backup-generation.XXXXXXXX').always_return('stdout' => "/fixture/helper\n")
    expect_upload('nest/hermes-backup-generation').with_destination('/fixture/helper')
    allow_any_command.error_with('kind' => 'fixture/busy', 'msg' => 'retention lock busy').be_called_times(1)
    expect(run_plan('nest::app::hermes::retain_generation', params).ok?).to be(false)
  end
end
