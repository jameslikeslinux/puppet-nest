# frozen_string_literal: true

require 'fileutils'
require 'pdk/util/puppet_version'
require 'pdk/util/ruby_version'
require 'pdk/cli/exec/command'

# The image build resolves the real Nest Gemfile through its authenticated
# sources. Keep that source-aware lock: Bundler cannot reconstruct fenced
# private sources from installed gemspecs alone, even with --local.
module NestPdkOfflineBundle
  def ensure_bundle!(gem_overrides = {})
    return super unless ENV['NEST_PDK_OFFLINE'] == 'true'

    bundle = PDK::Util::Bundler::BundleHelper.new
    return unless bundle.gemfile?

    unless bundle.locked?
      lock = '/opt/nest-pdk/Gemfile.lock'
      unless File.file?(lock)
        raise PDK::CLI::FatalError, 'Offline PDK image has no build-resolved Nest lockfile. Rebuild the PDK image.'
      end

      FileUtils.cp(lock, bundle.gemfile_lock)
    end

    # Frozen check fails on changed requirements instead of silently updating
    # the lock, choosing a different source, or contacting a gem server.
    command = bundle.send(:bundle_command, 'exec', 'ruby', '-e', 'exit 0')
    command.update_environment(PDK::Util::Bundler::BundleHelper.gemfile_env(gem_overrides || {}).merge('BUNDLE_FROZEN' => 'true', 'BUNDLE_GEMFILE' => bundle.gemfile))
    result = command.execute!
    unless result[:exit_code].zero?
      PDK.logger.fatal(result.values_at(:stdout, :stderr).join("\n"))
      raise PDK::CLI::FatalError, 'Offline PDK dependency closure is missing or changed. Rebuild the image with the current module inputs; no online fallback was attempted.'
    end

    mark_as_bundled!(bundle.gemfile, gem_overrides)

    fixture_config = File.join(File.dirname(bundle.gemfile), '.fixtures.yml')
    return unless File.file?(fixture_config)

    cached_config = '/opt/nest-pdk/fixtures.yml'
    unless File.file?(cached_config) && File.binread(fixture_config) == File.binread(cached_config)
      raise PDK::CLI::FatalError, 'Offline PDK fixture requirements changed. Rebuild the image with the current module inputs.'
    end

    # Use spec_helper's supported fixture source selection. spec_prep still
    # runs normally, but links build-resolved modules rather than fetching.
    ENV['FIXTURES_YML'] = '/opt/nest-pdk/offline-fixtures.yml'
  end
end

PDK::Util::Bundler.singleton_class.prepend(NestPdkOfflineBundle)

# Gem-installed PDK otherwise queries RubyGems to choose Puppet before it
# even checks the bundle. Select from the same cache used by its subprocesses.
module NestPdkOfflinePuppetVersion
  private

  def rubygems_puppet_versions
    return super unless ENV['NEST_PDK_OFFLINE'] == 'true'

    require 'bundler'

    lock = '/opt/nest-pdk/Gemfile.lock'
    return [] unless File.file?(lock)

    specs = ::Bundler::LockfileParser.new(::Bundler.read_file(lock)).specs
    versions = specs.select { |spec| spec.name == 'puppet' }.map(&:version)
    versions & PDK::Util::RubyVersion.available_puppet_versions
  end
end

PDK::Util::PuppetVersion.prepend(NestPdkOfflinePuppetVersion)

# Bundler.with_unbundled_env restores its original environment snapshot.
# Carry the verified fixture selection explicitly to PDK subprocesses.
module NestPdkOfflineCommand
  protected

  def resolved_env_for_command
    environment = super
    return environment unless ENV['NEST_PDK_OFFLINE'] == 'true' && [:module, :pwd].include?(context)

    environment['PUPPET_GEM_VERSION'] ||= PDK::Util::PuppetVersion.latest_available[:gem_version].to_s
    environment.merge('BUNDLE_FROZEN' => 'true', 'FIXTURES_YML' => ENV['FIXTURES_YML'])
  end
end

PDK::CLI::Exec::Command.prepend(NestPdkOfflineCommand)
