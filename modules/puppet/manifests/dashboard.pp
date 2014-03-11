class puppet::dashboard (
    $target,
    $db_password,
    $secret_token,
) {
    $mysql = '/usr/bin/mysql --defaults-extra-file=/root/.my.cnf'

    Exec {
        user    => 'dashboard',
        cwd     => $target,
        require => [
            User['dashboard'],
            File[$target],
        ],
        timeout => 0,
    }

    group { 'dashboard':
        ensure => present,
    }

    user { 'dashboard':
        gid     => 'dashboard',
        home    => $target,
        comment => 'Puppet Dashboard',
        shell   => '/bin/bash',
        require => Group['dashboard'],
    }

    file { $target:
        ensure  => directory,
        mode    => '0755',
        owner   => 'dashboard',
        group   => 'dashboard',
        require => User['dashboard'],
    }

    users::profile { '/app/dashboard':
        user    => 'dashboard',
        source  => 'git://github.com/puppetlabs/puppet-dashboard.git',
        branch  => 'rails3',
        require => File[$target],
        notify  => [
            Exec['install-dashboard-deps'],
            Exec['precompile-production-assets'],
        ],
    }

    exec { 'create-dashboard-db':
        command  => "${mysql} -e \"create database dashboard; grant all on dashboard.* to 'dashboard'@'localhost' identified by '${db_password}'\"",
        unless   => "${mysql} dashboard -e quit",
        user     => 'root',
        require  => Class['mysql'],
    }

    file { "${target}/config/settings.yml":
        mode    => '600',
        owner   => 'dashboard',
        group   => 'dashboard',
        content => template('puppet/settings.yml.erb'),
        require => Users::Profile['/app/dashboard'],
    }

    file { "${target}/config/database.yml":
        mode    => '600',
        owner   => 'dashboard',
        group   => 'dashboard',
        content => template('puppet/database.yml.erb'),
        require => Users::Profile['/app/dashboard'],
        notify  => Exec['setup-dashboard-db'],
    }

    portage::package { [
        'dev-ruby/bundler',
        'dev-db/postgresql-base',
    ]:
        ensure => 'installed',
    }

    exec { 'install-dashboard-deps':
        command     => '/usr/bin/bundle install --path vendor/bundle',
        refreshonly => true,
        require     => [
            Portage::Package['dev-ruby/bundler'],
            Portage::Package['dev-db/postgresql-base'],
        ],
    }

    exec { 'setup-dashboard-db':
        command     => '/usr/bin/bundle exec rake db:setup',
        refreshonly => true,
        require     => [
            Exec['create-dashboard-db'],
            File["${target}/config/database.yml"],
            Exec['install-dashboard-deps'],
        ],
    }

    exec { 'precompile-production-assets':
        command     => '/usr/bin/bundle exec rake assets:precompile',
        environment => 'RAILS_ENV=production',
        refreshonly => true,
        require     => Exec['install-dashboard-deps'],
    }
}
