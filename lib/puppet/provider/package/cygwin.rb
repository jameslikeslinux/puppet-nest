# Mike Delaney <mike@mldelaney.io>
#
require 'puppet/provider/package'
require 'puppet/util/package'

Puppet::Type.type(:package).provide(:cygwin, :parent => Puppet::Provider::Package) do
  desc 'Install a package via Cygwin'
  confine :operatingsystem => :windows

  has_feature :versionable
  has_feature :uninstallable
  has_feature :installable
  has_feature :install_options
  has_feature :source

  attr_reader :install_dir

  self::REGISTRY_KEY = 'SOFTWARE\Cygwin\setup'

  self::BAD_CYGCHECK_LINES = [
    %r{Cygwin Package Information},
    %r{Package(\s+)Version}
  ]

  self::REGEX = %r{^([\S]+)\s+(([\d\S\.]{2,})(\-([\d\.])+)?)$}
  self::FIELDS = [:name, :version]

  # install_dir
  #
  # Look up the Cygwin install directory from the registry, if it isn't
  # found then return nil.
  #
  def self.install_dir
    return @install_dir if @install_dir

    require 'win32/registry'

    begin
      Win32::Registry::HKEY_LOCAL_MACHINE.open(self::REGISTRY_KEY) do |reg|
        @install_dir = reg['rootdir'].tr '/', '\\'
      end
    rescue StandardError => e
      Puppet.debug e
    end
  end

  # cygwin
  #
  # Executes a command against cygwin, or setup.exe, and returns
  # the output
  #
  def self.cygwin(*args)
    cygwin_cmd = File.join install_dir, 'cygwinsetup.exe'
    cmd = [ cygwin_cmd, '--no-desktop' ] + args
    Puppet::Util::Execution.execute(cmd)
  end

  # cygcheck
  #
  # Executes a command against Cygcheck and returns the
  # output
  #
  def self.cygcheck(*args)
    cygcheck_cmd = File.join install_dir, 'bin', 'cygcheck.exe'
    cmd = [ cygcheck_cmd ] + args
    Puppet::Util::Execution.execute(cmd)
  end

  # parse_cygcheck_line
  #
  # Shortcut method to parse a line from cygcheck
  #
  def self.parse_cygcheck_line(line)
    hash_from_line(line, self::REGEX, self::FIELDS)
  end

  # hash_from_line
  #
  # Takes a line from stdout and using the regular expression,
  # try to extract the fields from the output.
  #
  def self.hash_from_line(line, regex, fields)
    line.strip!
    hash = {}

    begin
      if match = regex.match(line)
        fields.zip(match.captures) { |f, v| hash[f] = v }
        hash[:provider] = self.name
        hash[:ensure] = hash[:version]
      end

    rescue StandardError => e
      Puppet.debug "Failed to parse line: #{line}"
      Puppet.debug e

    end

    hash
  end

  # instances
  #
  # Returns all instances of packages, due to Cygwin, this only actually
  # returns the installed packages.
  #
  def self.instances
    packages = []

    cygcheck('-c', '-d').each_line do |line|
      if hash = parse_cygcheck_line(line)
        packages << new(hash) unless hash.empty?
      end
    end
    packages
  end

  # ignore_line
  #
  # Cygcheck and Setup produce some lines of content that we
  # don't care about. This is a helper function to see if the
  # line matches any known 'fluff' line.
  #
  def ignore_line?(line)
    should_ignore = false

    self.class::BAD_CYGCHECK_LINES.each do |reg|
      should_ignore = line.match reg
      break if should_ignore
    end

    should_ignore
  end

  # query
  #
  # Get the current status of a package, if the package is not found
  # we'll return a simple hash that just has 'ensure' set to ':absent'
  #
  def query
    @property_hash = { :ensure => :absent }

    begin
      self.class.cygcheck('-c', '-d', self.name).each_line do |line|
        line.strip!
        next if ignore_line? line

        hash = self.class.parse_cygcheck_line(line)
        @property_hash = hash unless hash.empty?
      end

    rescue StandardError => e
      Puppet.debug e

    end

    @property_hash
  end

  def uninstall
    status = query
    return if status[:ensure] == :absent

    flags = ['-q', '-x', get(:name)]
    self.class.cygwin(flags)
  end

  def install
    if @resource[:name].nil?
      fail "You must provide the name of the package to install"
    end

    flags = ['-q', '-P', name]
    unless @resource[:install_options].nil?
      flags << @resource[:install_options]
    end

    unless @resource[:source].nil?
      flags = flags.concat ['-s', @resource[:source]]
    end

    self.class.cygwin(flags)
  end
end
