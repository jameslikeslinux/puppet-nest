require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'Pinned stage build bases' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-build-plan-spec-') }
  let(:normal) { "registry.example/nest/stage0@sha256:#{'a' * 64}" }
  let(:debug) { "registry.example/nest/stage0/debug@sha256:#{'b' * 64}" }
  let(:common) { { 'container' => 'fixture', 'variant' => 'server', 'build' => false, 'deploy' => false, 'qemu_user_targets' => [], 'registry' => 'localhost' } }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  def stage1(options = {})
    run_plan('nest::build::stage1', common.merge('cpu' => 'haswell').merge(options))
  end

  def stage2(options = {})
    run_plan('nest::build::stage2', common.merge('platform' => 'vanilla', 'cpu' => 'haswell').merge(options))
  end

  def debug_command(image)
    "podman run --name=fixture --pull=always --rm --volume=fixture-debug:/usr/lib/.debug  #{image} cp -a /usr/lib/debug/. /usr/lib/.debug\n"
  end

  def create_command(image, stage)
    if stage == 1
      'podman create --dns=172.22.4.3 --init --name=fixture --pids-limit=0 --pull=always --volume=/nest:/nest ' \
        "--volume=fixture-debug:/usr/lib/debug --volume=fixture-repos:/var/db/repos  #{image} sleep infinity\n"
    else
      "podman create --init --name=fixture --pull=always --volume=/nest:/nest   #{image} sleep infinity\n"
    end
  end

  [false, true].each do |refresh|
    it "preserves Stage 1 default normal/debug selection with refresh=#{refresh}" do
      base = refresh ? 'nest/stage1/server' : 'nest/stage0'
      allow_command('podman rm -f fixture')
      allow_command('podman volume rm -f fixture-debug')
      expect_command(debug_command("#{base}/debug:haswell"))
      expect_command(create_command("#{base}:haswell", 1))

      expect(stage1('refresh' => refresh).ok?).to be(true)
    end

    it "passes both exact Stage 1 bases with refresh=#{refresh}" do
      allow_command('podman rm -f fixture')
      allow_command('podman volume rm -f fixture-debug')
      expect_command(debug_command(debug))
      expect_command(create_command(normal, 1))

      expect(stage1('refresh' => refresh, 'from_image' => normal, 'from_image_debug' => debug).ok?).to be(true)
    end

    it "preserves Stage 2 default selection with refresh=#{refresh}" do
      base = refresh ? 'nest/stage2/server:vanilla' : 'nest/stage1/server/debug:haswell'
      allow_command('podman rm -f fixture')
      expect_command(create_command(base, 2))

      expect(stage2('refresh' => refresh).ok?).to be(true)
    end

    it "passes the exact Stage 2 base with refresh=#{refresh}" do
      allow_command('podman rm -f fixture')
      expect_command(create_command(debug, 2))

      expect(stage2('refresh' => refresh, 'from_image' => debug).ok?).to be(true)
    end
  end

  it 'rejects either missing Stage 1 pair member before any container command' do
    expect(stage1('from_image' => normal).ok?).to be(false)
    expect(stage1('from_image_debug' => debug).ok?).to be(false)
  end

  it 'rejects mutable or malformed Stage 1 pair members before any container command' do
    ['nest/stage0:haswell', '', "#{normal};touch /unsafe", "#{normal}\n"].each do |invalid|
      expect(stage1('from_image' => invalid, 'from_image_debug' => debug).ok?).to be(false)
      expect(stage1('from_image' => normal, 'from_image_debug' => invalid).ok?).to be(false)
    end
  end

  it 'rejects mutable or malformed Stage 2 bases before any container command' do
    ['nest/stage1/server/debug:haswell', '', "#{debug};touch /unsafe", "#{debug}\n"].each do |invalid|
      expect(stage2('from_image' => invalid).ok?).to be(false)
    end
  end

  it 'refuses to claim pinned inputs were consumed by an existing container' do
    expect(stage1('init' => false, 'from_image' => normal, 'from_image_debug' => debug).ok?).to be(false)
    expect(stage2('init' => false, 'from_image' => debug).ok?).to be(false)
  end

  it 'retains existing-container compatibility without new pin assertions' do
    expect(stage1('init' => false).ok?).to be(true)
    expect(stage2('init' => false).ok?).to be(true)
  end
end
