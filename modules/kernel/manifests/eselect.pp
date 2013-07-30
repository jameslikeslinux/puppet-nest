define kernel::eselect (
    $set = $name,
) {
    exec { "eselect-kernel-${set}":
        command => "/usr/bin/eselect kernel set '${set}'",
        unless  => "/usr/bin/eselect kernel show | /bin/grep '${set}'",
    }
}
