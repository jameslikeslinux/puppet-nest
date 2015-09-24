class nest::role::work_system {
    class { 'openafs':
        thiscell => 'glue.umd.edu',
    }

    class { 'skype': }
}
