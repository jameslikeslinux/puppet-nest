require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'Generic tool frozen inputs and candidate publication' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-tool-inputs-spec-') }
  let(:pins) { { 'gentoo' => 'a' * 40, 'nest' => 'b' * 40, 'haskell' => 'c' * 40 } }
  let(:base) { "registry.example/nest/stage1/server@sha256:#{'d' * 64}" }
  let(:image) { 'registry.example/nest/tools/llama.cpp:candidate-111-fixture' }
  let(:reference) { "registry.example/nest/tools/llama.cpp@sha256:#{'e' * 64}" }
  let(:options) do
    { 'container' => 'fixture', 'cpu' => 'zen5', 'tool' => 'llama.cpp', 'build' => true,
      'deploy' => true, 'init' => true, 'candidate' => '111-fixture', 'from_image' => base,
      'repo_revisions' => pins, 'qemu_user_targets' => [], 'registry' => 'registry.example', 'registry_username' => nil }
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
    expect_command('podman volume rm -f fixture-repos').not_be_called
    expect_command('podman volume rm -f fixture-frozen-repos')
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values])
  end

  it 'refuses malformed or incomplete inputs before login or container commands' do
    expect_command(%r{podman }).not_be_called
    [{ 'candidate' => '' }, { 'candidate' => 'x;touch /unsafe' }, { 'build' => false }, { 'deploy' => false },
     { 'init' => false }, { 'from_image' => nil }, { 'from_image' => '' }, { 'from_image' => 'base:latest' },
     { 'registry' => 'localhost' }, { 'tag' => 'latest' }, { 'repo_revisions' => {} },
     { 'repo_revisions' => pins.merge('extra' => 'f' * 40) }, { 'repo_revisions' => pins.merge('nest' => 'main') },
     { 'repo_revisions' => pins.reject { |key, _| key == 'haskell' } },
     { 'extra_volumes' => ['/unsafe:/var/db/repos'] }].each do |override|
      expect(run_plan('nest::build::tool', options.merge(override)).ok?).to be(false)
    end
  end

  it 'allows only the exact read-only PDK credential mount with frozen repositories' do
    expect_command(%r{podman }).not_be_called
    [['/etc/gemrc:/etc/gemrc'], ['/etc/gemrc:/var/db/repos:ro'],
     ['/etc/gemrc:/etc/gemrc:ro', '/unsafe:/var/db/repos'], ['/etc:/etc:ro']].each do |mounts|
      expect(run_plan('nest::build::tool', options.merge('tool' => 'pdk', 'extra_volumes' => mounts)).ok?).to be(false)
    end
    expect(run_plan('nest::build::tool', options.merge('extra_volumes' => ['/etc/gemrc:/etc/gemrc:ro'])).ok?).to be(false)
  end

  [false, true].each do |refresh|
    it "consumes exact isolated inputs and returns a candidate digest with refresh=#{refresh}" do
      prepare_mocks
      expect_command("podman create --init --name=fixture --pull=always --volume=/nest:/nest  --volume=fixture-frozen-repos:/var/db/repos:nocopy  #{base} sleep infinity\n")
      expect_command('podman commit --change CMD=/bin/zsh fixture registry.example/nest/tools/llama.cpp:zen5').not_be_called
      expect_command("podman commit --change CMD=/bin/zsh fixture #{image}")
      expect_command(%r{podman push }).not_be_called
      expect_script('nest/build/publish-image.sh').with_params('arguments' => [image]).always_return('stdout' => "#{reference}\n")
      result = run_plan('nest::build::tool', options.merge('refresh' => refresh))
      expect(result.ok?).to be(true)
      expect(result.value).to eq('image' => reference)
    end
  end

  it 'stops before configuration and publication on failed repository preparation' do
    allow_any_command
    expect_script('nest/build/freeze-repos.py').error_with('msg' => 'Missing commit', 'kind' => 'fixture/fetch')
    expect_command(%r{podman commit }).not_be_called
    expect(run_plan('nest::build::tool', options).ok?).to be(false)
  end

  it 'stops publication on repository drift after the real catalog boundary' do
    allow_any_command
    allow_apply_prep
    allow_apply
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values]).error_with('msg' => 'Changed HEAD', 'kind' => 'fixture/drift')
    expect_command(%r{podman commit }).not_be_called
    expect(run_plan('nest::build::tool', options).ok?).to be(false)
  end

  it 'does not return an accepted candidate after publication failure' do
    prepare_mocks
    expect_script('nest/build/publish-image.sh').error_with('msg' => 'Push failed', 'kind' => 'fixture/push')
    expect(run_plan('nest::build::tool', options).ok?).to be(false)
  end

  it 'rejects mutable, malformed and wrong-repository publisher results' do
    [image, 'not-an-image', "other.example/tool@sha256:#{'e' * 64}"].each do |bad|
      prepare_mocks
      expect_script('nest/build/publish-image.sh').always_return('stdout' => "#{bad}\n")
      expect(run_plan('nest::build::tool', options).ok?).to be(false)
    end
  end

  it 'preserves the legacy fresh base, cached repositories and CPU publication' do
    allow_any_command
    allow_apply_prep
    allow_apply
    expect_command('eix-sync -aq')
    expect_command("podman create --init --name=fixture --pull=always --volume=/nest:/nest  --volume=fixture-repos:/var/db/repos  nest/stage1/server:zen5 sleep infinity\n")
    expect_command('podman commit --change CMD=/bin/zsh fixture registry.example/nest/tools/llama.cpp:zen5')
    expect_command('podman push registry.example/nest/tools/llama.cpp:zen5')
    expect_script('nest/build/freeze-repos.py').not_be_called
    expect_script('nest/build/publish-image.sh').not_be_called
    expect(run_plan('nest::build::tool', options.merge('candidate' => nil, 'from_image' => nil, 'repo_revisions' => nil)).ok?).to be(true)
  end

  it 'preserves a legacy refresh and explicit publication tag' do
    allow_any_command
    expect_command("podman create --init --name=fixture --pull=always --volume=/nest:/nest  --volume=fixture-repos:/var/db/repos  registry.example/nest/tools/llama.cpp:retained sleep infinity\n")
    expect_command('podman commit --change CMD=/bin/zsh fixture registry.example/nest/tools/llama.cpp:retained')
    expect_command('podman push registry.example/nest/tools/llama.cpp:retained')
    expect(run_plan('nest::build::tool', options.merge('candidate' => nil, 'from_image' => nil, 'repo_revisions' => nil,
                                                     'build' => false, 'refresh' => true, 'tag' => 'retained')).ok?).to be(true)
  end
end
