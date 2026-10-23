require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'PDK frozen candidate wrapper' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-pdk-candidate-spec-') }
  let(:pins) { { 'gentoo' => 'a' * 40, 'nest' => 'b' * 40, 'haskell' => 'c' * 40 } }
  let(:base) { "registry.example/nest/stage1/server@sha256:#{'d' * 64}" }
  let(:image) { 'registry.example/nest/tools/pdk:candidate-111-fixture' }
  let(:reference) { "registry.example/nest/tools/pdk@sha256:#{'e' * 64}" }
  let(:commit) do
    "podman commit --change CMD=/bin/zsh --change ENV=PDK_DISABLE_ANALYTICS=true --change ENV=NEST_PDK_OFFLINE=true --change WORKDIR=/module fixture #{image}"
  end
  let(:smoke) { 'sh -c "cd /module && pdk new class smoke && pdk new task smoke && bundle install && pdk validate && pdk test unit --tests=spec/classes/smoke_spec.rb"' }
  let(:cache) { 'sh -c "cd /module && NEST_PDK_OFFLINE=false ruby /opt/pdk-cache-nest.rb"' }
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

  def results(targets, error = false)
    Bolt::ResultSet.new(targets.map do |target|
      if error
        Bolt::Result.from_exception(target, Bolt::Error.new('Fixture failure', 'fixture/failed'))
      else
        Bolt::Result.for_command(target, { 'stdout' => '', 'stderr' => '', 'exit_code' => 0 }, 'command', '', [])
      end
    end)
  end

  def prepare_mocks
    allow_any_command
    allow_apply_prep
    allow_apply
    expect_command('eix-sync -aq').not_be_called
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values]).be_called_times(2)
  end

  it 'refuses incomplete candidates before any container command' do
    commands = []
    allow_any_command.return do |targets:, command:, **_options|
      commands << command
      results(targets)
    end
    invalid = [{ 'candidate' => '' }, { 'candidate' => 'x;false' }, { 'cpu' => 'zen5' }, { 'build' => false },
               { 'deploy' => false }, { 'init' => false }, { 'from_image' => nil }, { 'from_image' => 'base:latest' },
               { 'repo_revisions' => nil }, { 'repo_revisions' => {} }, { 'repo_revisions' => pins.merge('nest' => 'main') },
               { 'registry' => 'localhost' }, { 'registry' => 'unsafe;false' }, { 'tag' => 'latest' },
               { 'registry_username' => 'fixture' }, { 'registry_password' => 'fixture-not-a-credential' }]
    invalid.each { |override| expect(run_plan('nest::build::pdk', options.merge(override)).ok?).to be(false) }
    expect(commands).to be_empty
  end

  ['haswell', 'cortex-a53', 'sifive-u74'].each do |cpu|
    [false, true].each do |refresh|
      it "preserves generated-module smoke and committed Nest closure for #{cpu} with refresh=#{refresh}" do
        prepare_mocks
        expect_command(smoke)
        expect_command("bash -o pipefail -c 'git archive HEAD | podman cp - fixture:/module'")
        expect_command(cache)
        expect_command(commit)
        expect_command('podman push registry.example/nest/tools/pdk:haswell').not_be_called
        expect_script('nest/build/publish-image.sh').with_params('arguments' => [image]).always_return('stdout' => "#{reference}\n")
        result = run_plan('nest::build::pdk', options.merge('cpu' => cpu, 'refresh' => refresh))
        expect(result.ok?).to be(true)
        expect(result.value).to eq('image' => reference)
      end
    end
  end

  ['pdk new module --skip-interview build /module',
   'sh -c "cd /module && pdk new class smoke && pdk new task smoke && bundle install && pdk validate && pdk test unit --tests=spec/classes/smoke_spec.rb"',
   "bash -o pipefail -c 'git archive HEAD | podman cp - fixture:/module'",
   'sh -c "cd /module && NEST_PDK_OFFLINE=false ruby /opt/pdk-cache-nest.rb"'].each do |command|
    it "never publishes after #{command} fails" do
      allow_any_command
      allow_apply_prep
      allow_apply
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values])
      expect_command(command).error_with('msg' => 'Fixture failure', 'kind' => 'fixture/smoke')
      expect_command(commit).not_be_called
      expect_script('nest/build/publish-image.sh').not_be_called
      expect(run_plan('nest::build::pdk', options).ok?).to be(false)
    end
  end

  it 'refuses repository drift after smoke before commit' do
    allow_any_command
    allow_apply_prep
    allow_apply
    checks = 0
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values]).be_called_times(2).return do |targets:, **_options|
      checks += 1
      results(targets, checks == 2)
    end
    expect_command(commit).not_be_called
    expect_script('nest/build/publish-image.sh').not_be_called
    expect(run_plan('nest::build::pdk', options).ok?).to be(false)
  end

  it 'refuses failed final stop before commit' do
    prepare_mocks
    stops = 0
    expect_command('podman stop fixture').be_called_times(2).return do |targets:, **_options|
      stops += 1
      results(targets, stops == 2)
    end
    expect_command(commit).not_be_called
    expect_script('nest/build/publish-image.sh').not_be_called
    expect(run_plan('nest::build::pdk', options).ok?).to be(false)
  end

  it 'refuses failed commit before publication' do
    prepare_mocks
    expect_command(commit).error_with('msg' => 'Fixture failure', 'kind' => 'fixture/commit')
    expect_script('nest/build/publish-image.sh').not_be_called
    expect(run_plan('nest::build::pdk', options).ok?).to be(false)
  end

  it 'does not accept failed publication' do
    prepare_mocks
    expect_script('nest/build/publish-image.sh').error_with('msg' => 'Fixture failure', 'kind' => 'fixture/push')
    expect(run_plan('nest::build::pdk', options).ok?).to be(false)
  end

  it 'refuses mutable and wrong-project publisher results' do
    [image, "registry.example/nest/tools/bolt@sha256:#{'e' * 64}"].each do |bad|
      prepare_mocks
      expect_script('nest/build/publish-image.sh').always_return('stdout' => "#{bad}\n")
      expect(run_plan('nest::build::pdk', options).ok?).to be(false)
    end
  end

  it 'preserves legacy CPU-tag publication after PDK smoke and cache capture' do
    allow_any_command
    allow_apply_prep
    allow_apply
    expect_command('eix-sync -aq')
    expect_command(smoke)
    expect_command(cache)
    legacy_image = 'registry.example/nest/tools/pdk:haswell'
    expect_command("podman commit --change CMD=/bin/zsh --change ENV=PDK_DISABLE_ANALYTICS=true --change ENV=NEST_PDK_OFFLINE=true --change WORKDIR=/module fixture #{legacy_image}")
    expect_command("podman push #{legacy_image}")
    expect_script('nest/build/publish-image.sh').not_be_called
    expect_script('nest/build/freeze-repos.py').not_be_called
    legacy = options.merge('candidate' => nil, 'from_image' => nil, 'repo_revisions' => nil)
    expect(run_plan('nest::build::pdk', legacy).ok?).to be(true)
  end
end
