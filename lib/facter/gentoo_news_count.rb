Facter.add('gentoo_news_count') do
  confine :osfamily => 'Gentoo'
  setcode do
    Facter::Core::Execution.execute('/usr/bin/eselect news count').to_i
  end
end
