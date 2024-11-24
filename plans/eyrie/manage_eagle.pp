# Manage the state of Eagle nodes through its console
#
# @param targets Nodes to manage or none to manage the chassis
# @param power Action to take on the nodes
plan nest::eyrie::manage_eagle (
  Enum['off', 'on', 'reset', 'status'] $power,
  Optional[TargetSpec] $targets = undef,
) {
  $pson_pin      = 17
  $pscontrol_pin = 27
  $name_to_pin   = {
    'eagle'   => 18,
    'eaglet1' => 23,
    'eaglet2' => 24,
    'eaglet3' => 25,
    'eaglet4' => 8,
    'eaglet5' => 7,
    'eaglet6' => 12,
  }

  if $targets {
    get_targets($targets).each |$node| {
      $pin = $name_to_pin[$node.name]
      if $pin {
        case $power {
          'off': {
            run_command("gpioset -l 0 ${pin}=0", 'eagle-console', "Power off node ${node.name}", {
              _run_as => 'root',
            })
          }

          'on': {
            run_command("gpioset -l 0 ${pin}=1", 'eagle-console', "Power on node ${node.name}", {
              _run_as => 'root',
            })
          }

          'reset': {
            run_command("gpioset -l -m time -s 1 0 ${pin}=0 && gpioset -l 0 ${pin}=1", 'eagle-console', "Reset node ${node.name}", {
              _run_as => 'root',
            })
          }

          default: {
            fail("Can't use power=${power} on ${node.name}")
          }
        }
      } else {
        out::message("Cannot manage node ${node.name} from this console")
      }
    }
  } else {
    $pson = run_command("gpioget 0 ${pson_pin}", 'eagle-console', "Get current power status", {
      _run_as => 'root',
    }).first.value['stdout'].str2bool

    case $power {
      'off': {
        if $pson {
          run_command("gpioset -m time -u 200000 0 ${pscontrol_pin}=1 && gpioset 0 ${pscontrol_pin}=0", 'eagle-console', 'Power off the chassis', {
            _run_as => 'root',
          })
        } else {
          out::message('The chassis is already off')
        }
      }

      'on': {
        if !$pson {
          run_command("gpioset -m time -u 200000 0 ${pscontrol_pin}=1 && gpioset 0 ${pscontrol_pin}=0", 'eagle-console', 'Power on the chassis', {
            _run_as => 'root',
          })
        } else {
          out::message('The chassis is already on')
        }
      }

      'reset': {
        if $pson {
          run_command("gpioset -m time -u 200000 0 ${pscontrol_pin}=1 && gpioset -m time -s 1 0 ${pscontrol_pin}=0 && gpioset -m time -u 200000 0 ${pscontrol_pin}=1 && gpioset 0 ${pscontrol_pin}=0", 'eagle-console', 'Reset off the chassis', {
            _run_as => 'root',
          })
        } else {
          out::message('The chassis is off')
        }
      }

      'status': {
        if $pson {
          $power_state = 'on'
        } else {
          $power_state = 'off'
        }

        out::message("The chassis is ${power_state}")
        return $power_state
      }
    }
  }
}
