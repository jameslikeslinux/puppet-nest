# @summary One-time bounded staged identity preparation for Agent Request 1928
# Remove this plan and its script once all 22 Stage3 roots are accepted.
plan nest::build::stage3_1928_identity (
  Enum['prepare', 'submit', 'download', 'verify'] $action,
  Enum['builder1', 'builder2', 'builder3', 'runner1', 'control1', 'control2', 'control3', 'storage1', 'storage2', 'storage3', 'storage4', 'eagle', 'kite', 'kestrel-console', 'falcon-console', 'lark', 'gateway', 'falcon', 'hawk', 'kestrel', 'owl', 'osprey'] $hostname,
) {
  run_script('nest/build/stage3_1928_identity.py', 'falcon',
    '_run_as' => 'root',
    'arguments' => [$action, $hostname],
    '_description' => "${action} isolated Stage3 identity for ${hostname}",
  )
}
