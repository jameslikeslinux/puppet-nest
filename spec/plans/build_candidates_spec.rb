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
    (stage == 1) ? common.merge('from_image_debug' => debug) : common.merge('platform' => 'vanilla')
  end

  def prepare_mocks
    allow_any_command
    allow_apply_prep
    allow_apply
  end

  def publish(image, digest)
    expect_script('nest/build/publish-image.sh').with_params('arguments' => [image]).always_return('stdout' => "#{image.sub(%r{:[^:]*$}, '')}@sha256:#{digest * 64}\n")
  end

  [1, 2].each do |stage|
    it "rejects incomplete candidate Stage #{stage} execution before any command" do
      [{ 'build' => false }, { 'deploy' => false }, { 'init' => false }, { 'from_image' => nil },
       { 'registry' => 'localhost' }, { 'candidate' => '' }, { 'candidate' => 'a;touch /unsafe' }].each do |override|
        expect(run_plan("nest::build::stage#{stage}", options(stage).merge(override)).ok?).to be(false)
      end
    end

    it "publishes Stage #{stage} candidates without ordinary aliases and returns exact refs" do
      prepare_mocks
      suffix = (stage == 1) ? 'haswell' : 'vanilla'
      expect_command("podman commit --change CMD=/bin/zsh fixture registry.example/nest/stage#{stage}/server:#{suffix}").not_be_called
      image = "registry.example/nest/stage#{stage}/server:candidate-111-fixture"
      expect_command("podman commit --change CMD=/bin/zsh fixture #{image}")
      publish(image, 'c')
      publish('registry.example/nest/stage1/server/debug:candidate-111-fixture', 'd') if stage == 1
      result = run_plan("nest::build::stage#{stage}", options(stage))
      expect(result.ok?).to be(true)
      expected = if stage == 1
                   { 'normal' => "registry.example/nest/stage1/server@sha256:#{'c' * 64}",
                     'debug' => "registry.example/nest/stage1/server/debug@sha256:#{'d' * 64}" }
                 else
                   { 'image' => "registry.example/nest/stage2/server@sha256:#{'c' * 64}" }
                 end
      expect(result.value).to eq(expected)
    end

    it "stops Stage #{stage} on publication failure without a successful result" do
      prepare_mocks
      expect_script('nest/build/publish-image.sh').error_with('msg' => 'Fixture remote push failed', 'kind' => 'fixture/push-failed')
      expect(run_plan("nest::build::stage#{stage}", options(stage)).ok?).to be(false)
    end
  end

  it 'does not return a partial Stage 1 pair after debug publication fails' do
    prepare_mocks
    publish('registry.example/nest/stage1/server:candidate-111-fixture', 'c')
    failure = expect_script('nest/build/publish-image.sh').with_params('arguments' => ['registry.example/nest/stage1/server/debug:candidate-111-fixture'])
    failure.error_with('msg' => 'Fixture debug readback failed', 'kind' => 'fixture/debug-failed')
    expect(run_plan('nest::build::stage1', options(1)).ok?).to be(false)
  end

  it 'rejects matching normal and debug digests' do
    prepare_mocks
    publish('registry.example/nest/stage1/server:candidate-111-fixture', 'c')
    publish('registry.example/nest/stage1/server/debug:candidate-111-fixture', 'c')
    expect(run_plan('nest::build::stage1', options(1)).ok?).to be(false)
  end
end
