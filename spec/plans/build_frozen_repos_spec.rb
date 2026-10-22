require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'Frozen stage repository inputs' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-frozen-spec-') }
  let(:pins) { { 'gentoo' => 'a' * 40, 'nest' => 'b' * 40, 'haskell' => 'c' * 40 } }
  let(:base) { "registry.example/base@sha256:#{'d' * 64}" }

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
    common = { 'container' => 'fixture', 'cpu' => 'haswell', 'variant' => 'server', 'build' => true,
               'deploy' => false, 'qemu_user_targets' => [], 'registry' => 'localhost', 'from_image' => base, 'repo_revisions' => pins }
    (stage == 1) ? common.merge('from_image_debug' => base) : common.merge('platform' => 'vanilla')
  end

  def mocks
    allow_any_command
    allow_apply_prep
    allow_apply
    expect_command('eix-sync -aq').not_be_called
    expect_command('podman volume rm -f fixture-frozen-repos')
  end

  [1, 2].each do |stage|
    it "rejects incomplete Stage #{stage} pins before any command" do
      [{}, pins.reject { |key, _| key == 'haskell' }, pins.merge('extra' => 'e' * 40),
       pins.merge('nest' => 'main'), pins.merge('gentoo' => "#{'a' * 40}\n")].each do |bad|
        expect(run_plan("nest::build::stage#{stage}", options(stage).merge('repo_revisions' => bad)).ok?).to be(false)
      end
    end

    it "rejects an existing or unbuilt Stage #{stage} container and unpinned base before mutation" do
      [{ 'init' => false }, { 'build' => false }, { 'from_image' => nil }].each do |override|
        expect(run_plan("nest::build::stage#{stage}", options(stage).merge(override)).ok?).to be(false)
      end
    end

    it "prepares exact Stage #{stage} inputs and checks them after catalogs without syncing" do
      mocks
      prefix = 'podman create '
      prefix += '--dns=172.22.4.3 ' if stage == 1
      prefix += '--init --name=fixture '
      prefix += '--pids-limit=0 ' if stage == 1
      prefix += '--pull=always --volume=/nest:/nest '
      prefix += '--volume=fixture-debug:/usr/lib/debug ' if stage == 1
      expect_command("#{prefix}--volume=fixture-frozen-repos:/var/db/repos:nocopy  #{base} sleep infinity\n")
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values]).be_called_times(2)
      expect(run_plan("nest::build::stage#{stage}", options(stage)).ok?).to be(true)
    end

    it "stops Stage #{stage} before profile/package work after repository preparation failure" do
      mocks
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values]).error_with('msg' => 'Missing commit', 'kind' => 'fixture/fetch')
      expect_command(%r{eselect profile}).not_be_called
      expect(run_plan("nest::build::stage#{stage}", options(stage)).ok?).to be(false)
    end

    it "stops Stage #{stage} publication on observed repository drift" do
      mocks
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['prepare', *pins.values])
      expect_script('nest/build/freeze-repos.py').with_params('arguments' => ['check', *pins.values]).error_with('msg' => 'Changed HEAD', 'kind' => 'fixture/drift')
      expect_command(%r{podman commit}).not_be_called
      expect(run_plan("nest::build::stage#{stage}", options(stage)).ok?).to be(false)
    end
  end
end
