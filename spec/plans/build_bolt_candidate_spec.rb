require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'OpenBolt frozen candidate wrapper' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-bolt-candidate-spec-') }
  let(:pins) { { 'gentoo' => 'a' * 40, 'nest' => 'b' * 40, 'haskell' => 'c' * 40 } }
  let(:base) { "registry.example/nest/stage1/server@sha256:#{'d' * 64}" }
  let(:image) { 'registry.example/nest/tools/bolt:candidate-111-fixture' }
  let(:reference) { "registry.example/nest/tools/bolt@sha256:#{'e' * 64}" }
  let(:smoke) do
    <<~'SMOKE'
      ruby -rbolt -rbolt/transport/podman -rjson -e '
      connection = Bolt::Transport::Podman::Connection.allocate
      expected = [{"Id" => "first"}, {"Id" => "second"}]
      input = expected.map { |item| JSON.generate(item) }.join(10.chr)
      raise "Podman JSON parsing failed" unless connection.send(:extract_json, input) == expected
      '
    SMOKE
  end
  let(:commit) { "podman commit --change CMD=/bin/zsh --change ENV=BOLT_DISABLE_ANALYTICS=true --change ENV=BOLT_GEM=true fixture #{image}" }
  let(:options) do
    { 'container' => 'fixture', 'cpu' => 'haswell', 'build' => true, 'deploy' => true,
      'init' => true, 'candidate' => '111-fixture', 'from_image' => base, 'repo_revisions' => pins,
      'qemu_user_targets' => [], 'registry' => 'registry.example', 'registry_username' => nil, 'registry_password' => nil }
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

  def prepare_mocks
    allow_any_command
    allow_apply_prep
    allow_apply
    expect_command('eix-sync -aq').not_be_called
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values]).be_called_times(2)
  end

  def command_results(targets, error = false)
    Bolt::ResultSet.new(targets.map do |target|
      if error
        Bolt::Result.from_exception(target, Bolt::Error.new('Fixture failure', 'fixture/failed'))
      else
        Bolt::Result.for_command(target, { 'stdout' => '', 'stderr' => '', 'exit_code' => 0 }, 'command', '', [])
      end
    end)
  end

  it 'refuses incomplete candidate execution before container commands' do
    commands = []
    allow_any_command.return do |targets:, command:, **_options|
      commands << command
      command_results(targets)
    end
    [{ 'candidate' => '' }, { 'candidate' => 'x;false' }, { 'cpu' => 'zen5' }, { 'build' => false },
     { 'deploy' => false }, { 'init' => false }, { 'from_image' => nil }, { 'from_image' => 'base:latest' },
     { 'repo_revisions' => nil }, { 'repo_revisions' => {} }, { 'repo_revisions' => pins.merge('nest' => 'main') },
     { 'registry' => 'localhost' }, { 'registry' => 'unsafe;false' }, { 'tag' => 'latest' },
     { 'registry_username' => 'fixture' }, { 'registry_password' => 'fixture-not-a-credential' }].each do |override|
      expect(run_plan('nest::build::bolt', options.merge(override)).ok?).to be(false)
    end
    expect(commands).to be_empty
  end

  [false, true].each do |refresh|
    it "retains wrapper smoke, image environment and exact candidate digest with refresh=#{refresh}" do
      prepare_mocks
      expect_command('bolt')
      expect_command('bolt --version')
      expect_command(smoke)
      expect_command(commit)
      expect_command("podman push #{image}").not_be_called
      expect_command('podman push registry.example/nest/tools/bolt:haswell').not_be_called
      expect_script('nest/build/publish-image.sh').with_params('arguments' => [image]).always_return('stdout' => "#{reference}\n")
      result = run_plan('nest::build::bolt', options.merge('refresh' => refresh))
      expect(result.ok?).to be(true)
      expect(result.value).to eq('image' => reference)
    end
  end

  ['bolt', 'bolt --version', 'transport'].each do |step|
    it "never publishes after failed wrapper smoke #{step}" do
      allow_any_command
      allow_apply_prep
      allow_apply
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values])
      expect_command((step == 'transport') ? smoke : step).error_with('msg' => 'Fixture smoke failure', 'kind' => 'fixture/smoke')
      expect_command(commit).not_be_called
      expect_script('nest/build/publish-image.sh').not_be_called
      expect(run_plan('nest::build::bolt', options).ok?).to be(false)
    end
  end

  it 'refuses publication when frozen repositories fail validation' do
    allow_any_command
    allow_apply_prep
    allow_apply
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values]).error_with('msg' => 'Fixture drift', 'kind' => 'fixture/drift')
    expect_command(commit).not_be_called
    expect_script('nest/build/publish-image.sh').not_be_called
    expect(run_plan('nest::build::bolt', options).ok?).to be(false)
  end

  it 'does not accept a failed candidate push' do
    prepare_mocks
    expect_script('nest/build/publish-image.sh').error_with('msg' => 'Fixture push failure', 'kind' => 'fixture/push')
    expect(run_plan('nest::build::bolt', options).ok?).to be(false)
  end

  it 'refuses repository drift after wrapper smoke and before the final stop or commit' do
    allow_any_command
    allow_apply_prep
    allow_apply
    checks = 0
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values]).be_called_times(2).return do |targets:, **_options|
      checks += 1
      command_results(targets, checks == 2)
    end
    expect_command(smoke)
    expect_command('podman stop fixture')
    expect_command(commit).not_be_called
    expect_script('nest/build/publish-image.sh').not_be_called
    expect(run_plan('nest::build::bolt', options).ok?).to be(false)
  end

  it 'refuses failed final container stop after smoke without committing or publishing' do
    prepare_mocks
    stops = 0
    expect_command('podman stop fixture').be_called_times(2).return do |targets:, **_options|
      stops += 1
      command_results(targets, stops == 2)
    end
    expect_command(smoke)
    expect_command(commit).not_be_called
    expect_script('nest/build/publish-image.sh').not_be_called
    expect(run_plan('nest::build::bolt', options).ok?).to be(false)
  end

  it 'refuses failed commit without publishing or returning an accepted digest' do
    prepare_mocks
    expect_command(commit).error_with('msg' => 'Fixture commit failure', 'kind' => 'fixture/commit')
    expect_script('nest/build/publish-image.sh').not_be_called
    expect(run_plan('nest::build::bolt', options).ok?).to be(false)
  end

  it 'rejects mutable or wrong-project candidate results' do
    [image, "registry.example/nest/tools/pdk@sha256:#{'e' * 64}"].each do |bad|
      prepare_mocks
      expect_script('nest/build/publish-image.sh').always_return('stdout' => "#{bad}\n")
      expect(run_plan('nest::build::bolt', options).ok?).to be(false)
    end
  end

  it 'preserves the legacy wrapper smoke and CPU-tag publisher without candidate mode' do
    allow_any_command
    allow_apply_prep
    allow_apply
    expect_command('eix-sync -aq')
    expect_command('bolt')
    expect_command('bolt --version')
    expect_command(smoke)
    expect_command('podman commit --change CMD=/bin/zsh --change ENV=BOLT_DISABLE_ANALYTICS=true --change ENV=BOLT_GEM=true fixture registry.example/nest/tools/bolt:haswell')
    expect_command('podman push registry.example/nest/tools/bolt:haswell')
    expect_script('nest/build/publish-image.sh').not_be_called
    expect_script('nest/build/freeze-repos.py').not_be_called
    expect(run_plan('nest::build::bolt', options.merge('candidate' => nil, 'from_image' => nil, 'repo_revisions' => nil)).ok?).to be(true)
  end
end
