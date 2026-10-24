require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::app::hermes::backup verification admission' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-backup-verify-spec-') }
  let(:params) do
    { 'verify_only' => true, 'checkpoint' => 'fixture', 'expected_sha256' => 'a' * 64, 'max_age_seconds' => 3600 }
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

  ['quick', 'prune_only', 'cleanup_legacy', 'apply_legacy_cleanup', 'preserve_existing'].each do |option|
    it "rejects #{option} before even allocating a remote helper" do
      allow_any_command.not_be_called
      expect(run_plan('nest::app::hermes::backup', params.merge(option => true)).ok?).to be(false)
    end
  end

  ['checkpoint', 'expected_sha256', 'max_age_seconds'].each do |field|
    it "requires explicit #{field} before any remote action" do
      allow_any_command.not_be_called
      expect(run_plan('nest::app::hermes::backup', params.reject { |key, _value| key == field }).ok?).to be(false)
    end
  end

  ['expected_sha256', 'max_age_seconds'].each do |field|
    it "refuses verification-only #{field} on the default capture path" do
      allow_any_command.not_be_called
      expect(run_plan('nest::app::hermes::backup', field => params[field]).ok?).to be(false)
    end
  end

  it 'uploads the native verifier and returns its readback without initializing backup storage' do
    expect_command('mktemp /tmp/nest-hermes-backup-generation.XXXXXXXX').with_targets('owl').always_return('stdout' => "/fixture/helper\n")
    expect_upload('nest/hermes-backup-generation').with_targets('owl').with_destination('/fixture/helper')
    allow_any_command.return do |targets:, command:, **_options|
      expect(command).to include('/fixture/helper verify --backup-dir /nest/backup/hermes --checkpoint fixture')
      expect(command).to include("--expected-sha256 #{'a' * 64} --max-age-seconds 3600")
      expect(command).to include('runuser -u joy -- podman unshare')
      expect(command).not_to include('install -d', '--hermes-bin', '--stage-dir', '--retain', '--no-prune')
      Bolt::ResultSet.new(targets.map do |target|
        Bolt::Result.for_command(target, { 'stdout' => '{"action":"verified"}', 'stderr' => '', 'exit_code' => 0 }, 'command', command, [])
      end)
    end

    result = run_plan('nest::app::hermes::backup', params)

    expect(result.ok?).to be(true)
    expect(result.value.first.value['stdout']).to eq('{"action":"verified"}')
  end

  it 'propagates verifier refusal without a capture or pruning fallback' do
    expect_command('mktemp /tmp/nest-hermes-backup-generation.XXXXXXXX').always_return('stdout' => "/fixture/helper\n")
    expect_upload('nest/hermes-backup-generation').with_destination('/fixture/helper')
    allow_any_command.error_with('kind' => 'fixture/stale-backup', 'msg' => 'stale existing checkpoint').be_called_times(1)

    expect(run_plan('nest::app::hermes::backup', params).ok?).to be(false)
  end
end
