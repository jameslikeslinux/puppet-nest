class nest::base::gentoo {
  $news_read_command = "${trusted['certname']}.nest" ? {
    $nest::nestfs_hostname => '/usr/bin/eselect news read | /usr/bin/mailx -s "News from Gentoo" root',
    default                => '/usr/bin/eselect news read --quiet',
  }

  exec { 'eselect-news-read':
    command => $news_read_command,
    onlyif  => '/usr/bin/test `/usr/bin/eselect news count` -gt 0',
  }
}
