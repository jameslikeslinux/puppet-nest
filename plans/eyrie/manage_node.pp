# Manage the state of Eyrie nodes through its console
#
# @param targets Nodes to manage
# @param power Action to take on the nodes
plan nest::eyrie::manage_node (
  TargetSpec $targets,
  Enum['off', 'on', 'reset'] $power,
) {
  $name_to_pin = {
    'eagle'   => 18,
    'eaglet1' => 23,
    'eaglet2' => 24,
    'eaglet3' => 25,
    'eaglet4' => 8,
    'eaglet5' => 7,
    'eaglet6' => 12,
  }

  get_targets($targets).each |$node| {
    $pin = $name_to_pin[$node.name]
    if $pin {
      case $power {
        'off': {
          $gpio_cmd = "gpioset -l 0 ${pin}=0"
          $action   = 'Power off'
        }

        'on': {
          $gpio_cmd = "gpioset -l 0 ${pin}=1"
          $action   = 'Power on'
        }

        'reset': {
          $gpio_cmd = "gpioset -l -m time -s 1 0 ${pin}=0 && gpioset -l 0 ${pin}=1"
          $action   = 'Reset'
        }
      }

      run_command($gpio_cmd, 'eyrie-console', "${action} node ${node.name}", {
        _run_as => 'root',
      })
    } else {
      log::error("Cannot manage node ${node.name} from this console")
    }
  }
}
