# frozen_string_literal: true

require 'fileutils'
require 'pdk/util/bundler'
require 'bundler'
require 'yaml'

abort 'Nest PDK closure acquisition requires the build-time developer credential' if ENV['PUPPET_FORGE_TOKEN'].to_s.empty?
abort 'Run closure acquisition with NEST_PDK_OFFLINE=false' if ENV['NEST_PDK_OFFLINE'] == 'true'

# Use PDK's actual subprocess environment, not ~/.bundle/config's separate
# bundle path. Never persist source authentication in Bundler configuration.
bundle = PDK::Util::Bundler::BundleHelper.new
bundle.install!
lock = Bundler::LockfileParser.new(Bundler.read_file(bundle.gemfile_lock))
puppet = lock.specs.find { |spec| spec.name == 'puppet' }
abort 'The Nest closure did not resolve Puppet' unless puppet

# PDK supplies an exact Puppet override to validators and tests. Retain the
# matching dependency declaration, not just the same installed gem version.
bundle.install!(puppet: puppet.version.to_s)
FileUtils.mkdir_p('/opt/nest-pdk')
FileUtils.cp(bundle.gemfile_lock, '/opt/nest-pdk/Gemfile.lock')

# Ordinary unit runs also need their Forge/Git fixtures. Acquire them here,
# then retain only module content, not repository authentication/configuration.
command = bundle.send(:bundle_command, 'exec', 'rake', 'spec_prep')
command.update_environment('PUPPET_GEM_VERSION' => puppet.version.to_s)
result = command.execute!
abort result.values_at(:stdout, :stderr).join("\n") unless result[:exit_code].zero?
FileUtils.cp('.fixtures.yml', '/opt/nest-pdk/fixtures.yml')
FileUtils.mkdir_p('/opt/nest-pdk/modules')
Dir.glob('spec/fixtures/modules/*').each do |path|
  next if File.symlink?(path)

  destination = File.join('/opt/nest-pdk/modules', File.basename(path))
  FileUtils.rm_rf(destination)
  FileUtils.cp_r(path, destination)
  Dir.glob(File.join(destination, '**', '.git'), File::FNM_DOTMATCH).each { |git| FileUtils.rm_rf(git) }
end
symlinks = Dir.glob('/opt/nest-pdk/modules/*').to_h { |path| [File.basename(path), path] }
File.write('/opt/nest-pdk/offline-fixtures.yml', { 'fixtures' => { 'symlinks' => symlinks } }.to_yaml)
