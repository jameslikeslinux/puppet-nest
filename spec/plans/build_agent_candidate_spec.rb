require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'Agent frozen candidate wrapper' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-agent-candidate-spec-') }
  let(:pins) { { 'gentoo' => 'a' * 40, 'nest' => 'b' * 40, 'haskell' => 'c' * 40 } }
  let(:base) { "registry.example/nest/stage1/server@sha256:#{'d' * 64}" }
  let(:image) { 'registry.example/nest/tools/agent:candidate-111-fixture' }
  let(:reference) { "registry.example/nest/tools/agent@sha256:#{'e' * 64}" }
  let(:commit) { "podman commit --change CMD=/bin/zsh fixture #{image}" }
  let(:smokes) do
    ['print nest-agent-terminal-smoke', 'glab --version', 'git --version'].map do |command|
      "podman exec fixture /bin/zsh -lc '#{command}'"
    end
  end
  let(:options) do
    { 'container' => 'fixture', 'cpu' => 'zen5', 'build' => true, 'deploy' => true,
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

  it 'refuses incomplete candidates before any container command' do
    commands = []
    allow_any_command.return do |targets:, command:, **_options|
      commands << command
      command_results(targets)
    end
    [{ 'candidate' => '' }, { 'candidate' => 'x;false' }, { 'cpu' => 'haswell' }, { 'build' => false },
     { 'deploy' => false }, { 'init' => false }, { 'from_image' => nil }, { 'from_image' => 'base:latest' },
     { 'repo_revisions' => nil }, { 'repo_revisions' => {} }, { 'repo_revisions' => pins.merge('nest' => 'main') },
     { 'registry' => 'localhost' }, { 'registry' => 'unsafe;false' }, { 'tag' => 'latest' },
     { 'registry_username' => 'fixture' }, { 'registry_password' => 'fixture-not-a-credential' }].each do |override|
      expect(run_plan('nest::build::agent', options.merge(override)).ok?).to be(false)
    end
    expect(commands).to be_empty
  end

  [false, true].each do |refresh|
    it "preserves runtime smoke and exact inputs before candidate publication with refresh=#{refresh}" do
      prepare_mocks
      smokes.each { |command| expect_command(command) }
      expect_command(commit)
      expect_command('podman push registry.example/nest/tools/agent:latest').not_be_called
      expect_script('nest/build/publish-image.sh').with_params('arguments' => [image]).always_return('stdout' => "#{reference}\n")
      result = run_plan('nest::build::agent', options.merge('refresh' => refresh))
      expect(result.ok?).to be(true)
      expect(result.value).to eq('image' => reference)
    end
  end

  ['print nest-agent-terminal-smoke', 'glab --version', 'git --version'].each do |step|
    it "does not publish after runtime smoke failure in #{step}" do
      allow_any_command
      allow_apply_prep
      allow_apply
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values])
      expect_command("podman exec fixture /bin/zsh -lc '#{step}'").error_with('msg' => 'Fixture failure', 'kind' => 'fixture/smoke')
      expect_command(commit).not_be_called
      expect_script('nest/build/publish-image.sh').not_be_called
      expect(run_plan('nest::build::agent', options).ok?).to be(false)
    end
  end

  it 'refuses repository drift after smoke before final stop or commit' do
    allow_any_command
    allow_apply_prep
    allow_apply
    checks = 0
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values]).be_called_times(2).return do |targets:, **_options|
      checks += 1
      command_results(targets, checks == 2)
    end
    smokes.each { |command| expect_command(command) }
    expect_command('podman stop fixture')
    expect_command(commit).not_be_called
    expect_script('nest/build/publish-image.sh').not_be_called
    expect(run_plan('nest::build::agent', options).ok?).to be(false)
  end

  it 'refuses failed final stop before commit or publication' do
    prepare_mocks
    stops = 0
    expect_command('podman stop fixture').be_called_times(2).return do |targets:, **_options|
      stops += 1
      command_results(targets, stops == 2)
    end
    smokes.each { |command| expect_command(command) }
    expect_command(commit).not_be_called
    expect_script('nest/build/publish-image.sh').not_be_called
    expect(run_plan('nest::build::agent', options).ok?).to be(false)
  end

  it 'refuses failed commit before publication' do
    prepare_mocks
    expect_command(commit).error_with('msg' => 'Fixture failure', 'kind' => 'fixture/commit')
    expect_script('nest/build/publish-image.sh').not_be_called
    expect(run_plan('nest::build::agent', options).ok?).to be(false)
  end

  it 'does not accept a failed candidate publication' do
    prepare_mocks
    expect_script('nest/build/publish-image.sh').error_with('msg' => 'Fixture failure', 'kind' => 'fixture/push')
    expect(run_plan('nest::build::agent', options).ok?).to be(false)
  end

  it 'refuses mutable and wrong-project publisher results' do
    [image, "registry.example/nest/tools/bolt@sha256:#{'e' * 64}"].each do |bad|
      prepare_mocks
      expect_script('nest/build/publish-image.sh').always_return('stdout' => "#{bad}\n")
      expect(run_plan('nest::build::agent', options).ok?).to be(false)
    end
  end

  ['latest', 'retained'].each do |tag|
    it "preserves legacy smoke and #{tag} publication without candidate mode" do
      allow_any_command
      allow_apply_prep
      allow_apply
      expect_command('eix-sync -aq')
      smokes.each { |command| expect_command(command) }
      expect_command("podman commit --change CMD=/bin/zsh fixture registry.example/nest/tools/agent:#{tag}")
      expect_command("podman push registry.example/nest/tools/agent:#{tag}")
      expect_script('nest/build/publish-image.sh').not_be_called
      expect_script('nest/build/freeze-repos.py').not_be_called
      legacy = options.merge('candidate' => nil, 'from_image' => nil, 'repo_revisions' => nil)
      legacy['tag'] = tag unless tag == 'latest'
      expect(run_plan('nest::build::agent', legacy).ok?).to be(true)
    end
  end
end
