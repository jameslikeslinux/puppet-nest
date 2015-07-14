define users::profile (
    $directory = $name,
    $user,
    $source,
    $branch = 'master',
    $update,
) {
    Exec {
        cwd      => $directory,
        user     => $user,
        path     => '/usr/bin:/usr',
        provider => shell,
    }

    exec { "git-init-${directory}":
        command => "git init && git remote add origin '${source}'",
        unless  => "test -d '${directory}/.git'",
    }

    if $update {
        exec { "git-reset-${directory}":
            command  => "git reset --hard origin/${branch}",
            onlyif   => "git fetch origin && test \"`git show-ref -s --heads master`\" != \"`git show-ref -s origin/${branch}`\"",
            require  => Exec["git-init-${directory}"],
        }
    } else {
        exec { "git-reset-${directory}":
            command     => "git fetch origin && git reset --hard origin/${branch}",
            refreshonly => true,
            subscribe   => Exec["git-init-${directory}"],
        }
    }
}
