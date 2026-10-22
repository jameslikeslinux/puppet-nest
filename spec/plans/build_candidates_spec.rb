require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'Candidate stage publication' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-candidate-spec-') }
  let(:normal) { "registry.example/nest/stage0@sha256:#{'a' * 64}" }
  let(:debug) { "registry.example/nest/stage0/debug@sha256:#{'b' * 64}" }
  let(:common) do
    { 'container' => 'fixture', 'variant' => 'server', 'candidate' => '111-fixture', 'cpu' => 'haswell',
      'build' => true, 'init' => true, 'deploy' => true, 'registry' => 'registry.example', 'registry_username' => nil,
      'qemu_user_targets' => [], 'from_image' => normal }
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

  def options(stage)
    if stage.zero?
      common.reject { |key, _| key == 'variant' }.merge('cpu' => 'arm1176')
    elsif stage == 1
      common.merge('from_image_debug' => debug)
    else
      common.merge('platform' => 'vanilla')
    end
  end

  def prepare_mocks(stage = nil)
    allow_any_command
    allow_apply_prep
    allow_apply
    expect_script('nest/build/stage0-runtime.rb').be_called_times(3) if stage == 0
  end

  def publish(image, digest)
    expect_script('nest/build/publish-image.sh').with_params('arguments' => [image]).always_return('stdout' => "#{image.sub(%r{:[^:]*$}, '')}@sha256:#{digest * 64}\n")
  end

  [0, 1, 2].each do |stage|
    it "rejects incomplete candidate Stage #{stage} execution before any command" do
      [{ 'build' => false }, { 'deploy' => false }, { 'init' => false }, { 'from_image' => nil },
       { 'registry' => 'localhost' }, { 'candidate' => '' }, { 'candidate' => 'a;touch /unsafe' }].each do |override|
        expect(run_plan("nest::build::stage#{stage}", options(stage).merge(override)).ok?).to be(false)
      end
    end

    it "publishes Stage #{stage} candidates without ordinary aliases and returns exact refs" do
      prepare_mocks(stage)
      suffix = (stage == 1) ? 'haswell' : 'vanilla'
      repository = stage.zero? ? 'registry.example/nest/stage0' : "registry.example/nest/stage#{stage}/server"
      commit = stage.zero? ? 'podman commit --change CMD=/bin/bash --squash' : 'podman commit --change CMD=/bin/zsh'
      suffix = 'arm1176' if stage.zero?
      expect_command("#{commit} fixture #{repository}:#{suffix}").not_be_called
      image = "#{repository}:candidate-111-fixture"
      expect_command("#{commit} fixture #{image}")
      publish(image, 'c')
      publish("#{repository}/debug:candidate-111-fixture", 'd') if stage < 2
      result = run_plan("nest::build::stage#{stage}", options(stage))
      expect(result.ok?).to be(true)
      expected = if stage < 2
                   { 'normal' => "#{repository}@sha256:#{'c' * 64}",
                     'debug' => "#{repository}/debug@sha256:#{'d' * 64}" }
                 else
                   { 'image' => "registry.example/nest/stage2/server@sha256:#{'c' * 64}" }
                 end
      expect(result.value).to eq(expected)
    end

    it "stops Stage #{stage} on publication failure without a successful result" do
      prepare_mocks(stage)
      expect_script('nest/build/publish-image.sh').error_with('msg' => 'Fixture remote push failed', 'kind' => 'fixture/push-failed')
      expect(run_plan("nest::build::stage#{stage}", options(stage)).ok?).to be(false)
    end
  end

  [0, 1].each do |stage|
    it "does not return a partial Stage #{stage} pair after debug publication fails" do
      prepare_mocks(stage)
      repository = stage.zero? ? 'registry.example/nest/stage0' : 'registry.example/nest/stage1/server'
      publish("#{repository}:candidate-111-fixture", 'c')
      failure = expect_script('nest/build/publish-image.sh').with_params('arguments' => ["#{repository}/debug:candidate-111-fixture"])
      failure.error_with('msg' => 'Fixture debug readback failed', 'kind' => 'fixture/debug-failed')
      expect(run_plan("nest::build::stage#{stage}", options(stage)).ok?).to be(false)
    end

    it "rejects matching Stage #{stage} normal and debug digests" do
      prepare_mocks(stage)
      repository = stage.zero? ? 'registry.example/nest/stage0' : 'registry.example/nest/stage1/server'
      publish("#{repository}:candidate-111-fixture", 'c')
      publish("#{repository}/debug:candidate-111-fixture", 'c')
      expect(run_plan("nest::build::stage#{stage}", options(stage)).ok?).to be(false)
    end
  end

  it 'rejects Stage 0 mutable or raw Gentoo bases before login or container removal' do
    expect_command(%r{podman }).not_be_called
    ['nest/stage0:arm1176', "registry.example/gentoo/stage3@sha256:#{'a' * 64}"].each do |base|
      expect(run_plan('nest::build::stage0', options(0).merge('from_image' => base)).ok?).to be(false)
    end
  end

  it 'combines Stage 0 candidate outputs with complete frozen inputs without syncing' do
    prepare_mocks(0)
    pins = { 'gentoo' => 'a' * 40, 'nest' => 'b' * 40, 'haskell' => 'c' * 40 }
    expect_command('eix-sync -aq').not_be_called
    expect_command('emerge --sync').not_be_called
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
    expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values]).be_called_times(2)
    publish('registry.example/nest/stage0:candidate-111-fixture', 'c')
    publish('registry.example/nest/stage0/debug:candidate-111-fixture', 'd')
    expect(run_plan('nest::build::stage0', options(0).merge('repo_revisions' => pins)).ok?).to be(true)
  end

  it 'preserves ordinary Stage 0 normal/debug CPU aliases when candidate mode is absent' do
    prepare_mocks(0)
    expect_script('nest/build/publish-image.sh').not_be_called
    expect_command('podman commit --change CMD=/bin/bash --squash fixture registry.example/nest/stage0:arm1176')
    expect_command('podman commit --change CMD=/bin/bash fixture-debug registry.example/nest/stage0/debug:arm1176')
    expect_command('podman push registry.example/nest/stage0:arm1176')
    expect_command('podman push registry.example/nest/stage0/debug:arm1176')
    expect(run_plan('nest::build::stage0', options(0).merge('candidate' => nil)).ok?).to be(true)
  end
end
