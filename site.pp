if $trusted['certname'] in ['bolt', 'puppetdb'] {
  fail("${trusted['certname']} is not allowed to use Puppet")
}

include nest
