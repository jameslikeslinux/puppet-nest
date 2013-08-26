define postfix::alias (
    $recipient,
) {
    mailalias { $name:
        recipient => $recipient,
        target    => '/etc/mail/aliases',
        require   => Class['postfix'],
        notify    => Exec['/usr/bin/newaliases'],
    }

    exec { '/usr/bin/newaliases':
        refreshonly => true,
    }
}
