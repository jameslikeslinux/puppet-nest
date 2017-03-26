class nest::node::web {
  nest::wordpress { 'thestaticvoid':
    db_password   => 'fake',
    servername    => 'thestaticvoid.com',
    serveraliases => ['www.thestaticvoid.com'],
    ip            => ['45.63.8.234', 'fe80::32:33a:d68b:26ba'],
  }

  nest::revproxy { 'heloandnala.net':
    destination   => 'http://hawk:81/',
    serveraliases => ['www.heloandnala.net'],
  }
}
