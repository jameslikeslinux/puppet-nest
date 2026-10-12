# frozen_string_literal: true

# PDK's transitive dependencies can install JSON 3, whose parse options are
# keywords. OpenVox 8 still passes a positional hash. Patch only that call in
# installed OpenVox gems inside the PDK build; remove when upstream uses keywords.
paths = Gem::Specification.find_all_by_name('openvox').map do |spec|
  File.join(spec.full_gem_path, 'lib/puppet/util/json.rb')
end
raise 'No installed OpenVox JSON implementation found' if paths.empty?

old_call = '::JSON.parse(string, options)'
new_call = '::JSON.parse(string, **options)'
pending = paths.select { |path| File.read(path).include?(old_call) }
if ARGV.include?('--check')
  exit(pending.empty? ? 1 : 0)
end

pending.each do |path|
  File.write(path, File.read(path).gsub(old_call, new_call))
end
