module Puppet::Util::Portage
  # Util methods for Portage types and providers.
  #
  # @see http://dev.gentoo.org/~zmedico/portage/doc/man/ebuild.5.html 'man 5 ebuild section DEPEND'

  extend self

  CATEGORY_PATTERN = '[a-zA-Z0-9]+(?:-[a-zA-Z0-9]+)?'
  NAME_PATTERN     = '[\w+-]+'
  PACKAGE_PATTERN  = "(#{CATEGORY_PATTERN}/#{NAME_PATTERN})"
  COMPARE_PATTERN  = '([<>=~]|[<>]=)'
  VERSION_PATTERN  = '([\d.*]+[\w*-]*)'

  BASE_ATOM_REGEX      = Regexp.new "^#{PACKAGE_PATTERN}$"
  VERSIONED_ATOM_REGEX = Regexp.new "^#{COMPARE_PATTERN}#{PACKAGE_PATTERN}-#{VERSION_PATTERN}$"
  DEPEND_ATOM_REGEX    = Regexp.union BASE_ATOM_REGEX, VERSIONED_ATOM_REGEX

  # Determine if a string is a valid DEPEND atom
  #
  # @param [String] atom The string to validate as a DEPEND atom
  #
  # @return [TrueClass]
  # @return [FalseClass]
  def valid_atom?(atom)
    # Normalize the regular expression output to a boolean
    !!(atom =~ DEPEND_ATOM_REGEX)
  end

  # Determine if a string is a valid package name
  #
  # @param [String] package_name the string to validate as a package name
  #
  # @return [TrueClass]
  # @return [FalseClass]
  def valid_package?(package_name)
    !!(package_name =~ BASE_ATOM_REGEX)
  end

  # Determine if a string is a valid DEPEND atom version
  #
  # This validates a standalone version string. The format is an optional
  # comparator and a version string.
  #
  # @param [String] version_str The string to validate as a version string.
  #
  # @return [TrueClass]
  # @Return [FalseClass]
  def valid_version?(version_str)
    regex = Regexp.new "^#{COMPARE_PATTERN}?#{VERSION_PATTERN}$"
    !!(version_str =~ regex)
  end

  # Parse a string into the different components of a DEPEND atom.
  #
  # If the atom is versioned, the returned value will contain the keys
  # :package, :compare, and :version. If the atom is unversioned then it will
  # contain the key :package.
  #
  # @raise [Puppet::Util::Portage::AtomError]
  #
  # @param [String] atom The string to parse
  #
  # @return [Hash<Symbol, String>] The parsed values
  def parse_atom(atom)
    if (match = atom.match(BASE_ATOM_REGEX))
      {:package => match[1]}
    elsif (match = atom.match(VERSIONED_ATOM_REGEX))
      {:compare => (match[1] || '='), :package => match[2], :version => match[3]}
    else
      raise AtomError, "#{atom} is not a valid atom"
    end
  end

  # Parse out a combined compare and version into a hash
  #
  # @return [Hash]
  def parse_cmpver(cmpver)
    regex = Regexp.new("#{COMPARE_PATTERN}?#{VERSION_PATTERN}")
    if (match = cmpver.match regex)
      {:compare => match[1], :version => match[2]}
    else
      raise AtomError, "#{cmpver} is not a valid compare version"
    end
  end

  # Convert a hash describing an atom into a string
  #
  # @return [String]
  def format_atom(hash)
    str = ""

    if hash[:version]
      ver_hash = parse_cmpver(hash[:version])
      str << ver_hash[:compare]
      str << hash[:name]
      str << '-'
      str << ver_hash[:version]
    else
      str = hash[:name].dup
    end

    str
  end

  class AtomError < RuntimeError; end
end
