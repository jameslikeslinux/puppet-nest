define users::profile (
    $directory = $name,
    $user,
    $source,
    $branch = 'master',
) {
    Exec {
        cwd  => $directory,
        user => $user,
        path => '/usr/bin:/usr',
    }

    exec { "git-init-${directory}":
        command => "git init && git remote add origin '${source}'",
        unless  => "test -d '${directory}/.git'",
    }

    exec { "git-reset-${directory}":
        command  => "git reset --hard origin/${branch}",
        onlyif   => "git fetch origin && test \"`git show-ref -s --heads master`\" != \"`git show-ref -s origin/${branch}`\"",
        provider => 'shell',
        require  => Exec["git-init-${directory}"],
    }
}
