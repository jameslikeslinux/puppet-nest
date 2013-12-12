class profile::role::work_system {
    class { 'openafs':
        thiscell => 'glue.umd.edu',
    }
}
