ENV['STRICT_VARIABLES'] ||= 'no'

require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'
include RspecPuppetFacts

add_custom_fact :memory, {'system' => {'total_bytes' => '8589934592'}}
add_custom_fact :nest, {}
add_custom_fact :portage_cflags, '', :confine => 'gentoo-3-x86_64'
add_custom_fact :portage_cpu_flags_x86, '', :confine => 'gentoo-3-x86_64'
add_custom_fact :toolchain, 'x86_64-pc-linux-gnu', :confine => 'gentoo-3-x86_64'
add_custom_fact :mountpoints, {}, :confine => 'gentoo-3-x86_64'

RSpec.configure do |c|
  c.hiera_config = File.expand_path(File.join(__FILE__, '../fixtures/hiera.yaml'))
end
