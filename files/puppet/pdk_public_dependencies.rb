# frozen_string_literal: true

# Public dependency closure from a real authenticated PDK 3.6.1 module bundle
# (Bolt 5.1.0, Puppet 8.13.0, Facter 4.22.0). PuppetCore's index is not a
# complete mirror of RubyGems. Bundler's source fencing must not send these
# public dependencies to that index. Preserve module-authored declarations
# and all version constraints; only supply a source for otherwise implicit
# dependencies. Remove this hint when PuppetCore/Bundler resolves the public
# closure correctly without explicit declarations.
public_dependencies = [
  'CFPropertyList', 'addressable', 'aws-eventstream', 'aws-partitions', 'aws-sdk-core',
  'aws-sdk-ec2', 'aws-sigv4', 'base64', 'bcrypt_pbkdf', 'benchmark', 'bigdecimal', 'bindata', 'builder',
  'colored2', 'concurrent-ruby', 'connection_pool', 'cri', 'csv', 'deep_merge', 'ed25519', 'erubi',
  'faraday', 'faraday-follow_redirects', 'faraday-net_http', 'faraday-net_http_persistent',
  'fast_gettext', 'ffi', 'fiddle', 'forwardable', 'getoptlong', 'gettext', 'gettext-setup', 'gssapi',
  'gyoku', 'hiera-eyaml', 'highline', 'hocon', 'httpclient', 'io-console', 'jmespath', 'json', 'jwt',
  'little-plugger', 'locale', 'log4r', 'logger', 'logging', 'minitar', 'molinillo', 'multi_json', 'mutex_m',
  'net-http', 'net-http-persistent', 'net-protocol', 'net-scp', 'net-ssh', 'net-ssh-krb', 'nkf', 'nori',
  'optimist', 'orchestrator_client', 'ostruct', 'prime', 'public_suffix', 'puppet-resource_api',
  'puppet-strings', 'puppet_forge', 'puppetfile-resolver', 'r10k', 'racc', 'reline', 'rexml', 'rgen',
  'ruby_smb', 'rubyntlm', 'rubyzip', 'scanf', 'semantic_puppet', 'singleton', 'stringio', 'terminal-table',
  'text', 'thor', 'timeout', 'unicode-display_width', 'uri', 'windows_error', 'winrm', 'winrm-fs', 'yard'
]
declared = dependencies.map(&:name)
source 'https://rubygems.org' do
  dependencies.each do |dependency|
    dependency.source = @source if public_dependencies.include?(dependency.name) && dependency.source.nil?
  end
  public_dependencies.each do |name|
    gem name, require: false unless declared.include?(name)
  end
  # The template declares these only for Windows, while Bolt needs them on
  # Ruby/Linux too. Keep the template's constraints when adding that platform.
  ['CFPropertyList', 'bigdecimal'].each do |name|
    dependency = dependencies.find { |item| item.name == name }
    gem name, *dependency.requirement.as_list, platforms: :ruby, require: false if dependency
  end
end
