# frozen_string_literal: true

# PDK's transitive dependencies can install JSON 3, whose parse options are
# keywords and no longer accepts quirks_mode (scalar JSON is always accepted).
# Repair the installed dependencies only inside the PDK build. Remove each
# compatibility patch when its upstream dependency supports JSON 3.
patches = Gem::Specification.find_all_by_name('openvox').map do |spec|
  [File.join(spec.full_gem_path, 'lib/puppet/util/json.rb'),
   '::JSON.parse(string, options)', '::JSON.parse(string, **options)']
end
raise 'No installed OpenVox JSON implementation found' if patches.empty?
schemas = Gem::Specification.find_all_by_name('json-schema')
raise 'No installed json-schema implementation found' if schemas.empty?
patches += schemas.map do |spec|
  [File.join(spec.full_gem_path, 'lib/json-schema/validator.rb'),
   'JSON.parse(s, quirks_mode: true)', 'JSON.parse(s)']
end

pending = patches.select { |path, old_call, _new_call| File.read(path).include?(old_call) }
if ARGV.include?('--check')
  exit(pending.empty? ? 1 : 0)
end

pending.each do |path, old_call, new_call|
  File.write(path, File.read(path).gsub(old_call, new_call))
end
