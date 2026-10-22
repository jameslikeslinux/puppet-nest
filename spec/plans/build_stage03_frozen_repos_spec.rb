require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'Stage 0 and Stage 3 frozen repository inputs' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-stage03-frozen-spec-') }
  let(:pins) { { 'gentoo' => 'a' * 40, 'nest' => 'b' * 40, 'haskell' => 'c' * 40 } }
  let(:base) { "registry.example/nest/base@sha256:#{'d' * 64}" }

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
    common = { 'container' => 'fixture', 'build' => true, 'deploy' => false, 'qemu_user_targets' => [], 'repo_revisions' => pins }
    if stage.zero?
      common.merge('cpu' => 'arm1176', 'from_image' => base, 'registry' => 'localhost')
    else
      common.merge('hostname' => 'fixture-host', 'platform' => 'vanilla', 'variant' => 'server', 'stage2_image' => base)
    end
  end

  def mocks(stage)
    allow_any_command
    allow_apply_prep
    allow_apply
    expect_command('eix-sync -aq').not_be_called
    expect_command('emerge --sync').not_be_called
    expect_command('podman volume rm -f fixture-frozen-repos')
    expect_script('nest/build/stage0-runtime.rb').be_called_times(3) if stage.zero?
  end

  [0, 3].each do |stage|
    it "rejects incomplete or malformed Stage #{stage} pins before any command" do
      expect_command('podman rm -f fixture').not_be_called
      expect_command('podman volume rm -f fixture-debug').not_be_called
      expect_command('podman volume rm -f fixture-frozen-repos').not_be_called
      [{}, pins.reject { |key, _| key == 'haskell' }, pins.merge('extra' => 'e' * 40),
       pins.merge('nest' => 'main'), pins.merge('gentoo' => "#{'a' * 40}\n")].each do |bad|
        expect(run_plan("nest::build::stage#{stage}", options(stage).merge('repo_revisions' => bad)).ok?).to be(false)
      end
    end

    it "rejects existing or unbuilt Stage #{stage} containers and mutable bases before mutation" do
      expect_command('podman rm -f fixture').not_be_called
      expect_command('podman volume rm -f fixture-debug').not_be_called
      expect_command('podman volume rm -f fixture-frozen-repos').not_be_called
      key = stage.zero? ? 'from_image' : 'stage2_image'
      [{ 'init' => false }, { 'build' => false }, { key => nil }, { key => 'registry.example/nest/base:latest' }].each do |override|
        expect(run_plan("nest::build::stage#{stage}", options(stage).merge(override)).ok?).to be(false)
      end
    end

    it "prepares complete Stage #{stage} repositories and checks after configuration and before output" do
      mocks(stage)
      prefix = if stage.zero?
                 'podman create --dns=172.22.4.3 --env=LANG --init --name=fixture --pull=always --volume=/nest:/nest --volume=fixture-debug:/usr/lib/debug '
               else
                 'podman create --init --hostname=fixture-host --name=fixture --no-hosts --pull=always --volume=/falcon:/falcon --volume=/nest:/nest '
               end
      spaces = stage.zero? ? '  ' : '   '
      expect_command("#{prefix}--volume=fixture-frozen-repos:/var/db/repos:nocopy#{spaces}#{base} sleep infinity\n")
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values]).be_called_times(2)
      expect(run_plan("nest::build::stage#{stage}", options(stage)).ok?).to be(true)
    end

    it "stops Stage #{stage} before configuration or packages after preparation failure" do
      allow_any_command
      expect_command('podman volume rm -f fixture-frozen-repos')
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values]).error_with('msg' => 'Missing commit', 'kind' => 'fixture/fetch')
      expect_command(%r{emerge }).not_be_called
      expect_command(%r{eselect profile}).not_be_called
      expect(run_plan("nest::build::stage#{stage}", options(stage)).ok?).to be(false)
    end

    it "stops Stage #{stage} before package build or publication when a catalog drifts repositories" do
      allow_any_command
      allow_apply_prep
      allow_apply
      expect_script('nest/build/stage0-runtime.rb') if stage.zero?
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values]).error_with('msg' => 'Changed HEAD', 'kind' => 'fixture/drift')
      expect_command(%r{emerge --deep}).not_be_called
      expect_command(%r{podman commit}).not_be_called
      expect_command(%r{zsh -c .*rsync}).not_be_called
      expect(run_plan("nest::build::stage#{stage}", options(stage).merge('deploy' => true)).ok?).to be(false)
    end

    it "preserves the legacy Stage #{stage} sync and volume behavior without repository pins" do
      allow_any_command
      allow_apply_prep
      allow_apply
      expect_script('nest/build/stage0-runtime.rb').be_called_times(3) if stage.zero?
      expect_script('nest/build/freeze-repos.py').not_be_called
      expect_command('eix-sync -aq')
      expect_command('podman volume rm -f fixture-frozen-repos').not_be_called
      expect(run_plan("nest::build::stage#{stage}", options(stage).merge('repo_revisions' => nil)).ok?).to be(true)
    end
  end

  it 'refuses frozen raw Gentoo bootstrap instead of silently syncing or installing Git from floating inputs' do
    expect_command('podman rm -f fixture').not_be_called
    expect_command('podman volume rm -f fixture-debug').not_be_called
    expect_command('podman volume rm -f fixture-frozen-repos').not_be_called
    gentoo = "registry.example/gentoo/stage3@sha256:#{'e' * 64}"
    expect(run_plan('nest::build::stage0', options(0).merge('from_image' => gentoo)).ok?).to be(false)
  end
end
