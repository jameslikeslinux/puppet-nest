define dracut::modules(
    $crypt    = false,
    $mdraid   = false,
    $plymouth = false,
) {
    $crypt_module = $crypt ? {
        true    => 'crypt ',
        default => '',
    }

    $mdraid_module = $mdraid ? {
        true    => 'mdraid ',
        default => '',
    }

    $plymouth_module = $plymouth ? {
        true    => 'plymouth ',
        default => '',
    }

    $modules = [$crypt_module, $mdraid_module, $plymouth_module]

    portage::makeconf { 'dracut_modules':
        content => join($modules, ''),
    }
}
