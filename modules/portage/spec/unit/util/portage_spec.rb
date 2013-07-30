require 'spec_helper'

require 'puppet/util/portage'

describe Puppet::Util::Portage do
  describe "valid_atom?" do

    valid_atoms = [
      '=foo/bar-1.0.0',
      '>=foo/bar-1.0.0',
      '<=foo/bar-1.0.0',
      '>foo/bar-1.1.0',
      '<foo/bar-1.0.0',
      'foo1-bar2/messy_atom++',
    ]

    invalid_atoms = [
      'sys-devel-gcc',
      '=sys-devel/gcc',
      # version without quantifier
      'foo1-bar2/messy_atom++-1.0',
    ]

    valid_atoms.each do |atom|
      it "should accept '#{atom}' as a valid name" do
        Puppet::Util::Portage.valid_atom?(atom).should be_true
      end
    end

    invalid_atoms.each do |atom|
      it "should reject #{atom} as an invalid name" do
        Puppet::Util::Portage.valid_atom?(atom).should be_false
      end
    end
  end

  describe "valid_package?" do
    valid_packages = [
      'app-accessibility/brltty',
      'dev-libs/userspace-rcu',
      'sys-dev/gcc',
      'x11-wm/aewm++',
      'x11-themes/fvwm_sounds',
      'net-analyzer/nagios-check_logfiles',
      'dev-embedded/scratchbox-toolchain-cs2005q3_2-glibc2_5',
      'virtual/package-manager',
    ]

    invalid_packages = [
      'gcc',
      'sys-dev-gcc',
      '=app-admin/eselect-fontconfig-1.1',
    ]

    valid_packages.each do |package|
      it "should accept #{package} as valid" do
        Puppet::Util::Portage.valid_package?(package).should be_true
      end
    end

    invalid_packages.each do |package|
      it "should reject #{package} as invalid" do
        Puppet::Util::Portage.valid_package?(package).should be_false
      end
    end
  end

  describe "valid_version?" do
    comparators = %w{~ < > = <= >=}

    valid_versions = [
      '4.3.2-r4',
      '1.3',
      '0.5.2_pre20120527',
      '3.0_alpha12',
      '2.2*',
      '5.1-alpha*',
      '3.*.0',
    ]

    invalid_versions = [
      '!4.3.2-r4',
      '4.2.3>',
      'alpha',
      'alpha-2.4.1'
    ]

    valid_versions.each do |ver|
      it "should accept #{ver} as valid" do
        Puppet::Util::Portage.valid_version?(ver).should be_true
      end
    end

    describe 'with comparators' do
      comparators.each do |comp|
        valid_versions.each do |ver|
          ver_str = comp + ver
          it "should accept #{ver_str} as valid" do
            Puppet::Util::Portage.valid_version?(ver_str).should be_true
          end
        end
      end
    end

    invalid_versions.each do |ver|
      it "should reject #{ver} as invalid" do
        Puppet::Util::Portage.valid_version?(ver).should be_false
      end
    end
  end

  describe "parse_atom" do

    valid_base_atoms = [
      'app-accessibility/brltty',
      'dev-libs/userspace-rcu',
      'sys-dev/gcc',
    ]

    valid_base_atoms.each do |atom|
      it "should parse #{atom} as {:package => #{atom}}" do
        Puppet::Util::Portage.parse_atom(atom).should == {:package => atom}
      end
    end

    valid_atoms = [
      {
        :atom => 'dev-libs/glib-2.32.4-r1',
        :expected => {
          :package => 'dev-libs/glib',
          :version => '2.32.4-r1',
          :compare => '=',
        },
      },
      {
        :atom => '>=app-admin/puppet-3.0.1',
        :expected => {
          :package => 'app-admin/puppet',
          :version => '3.0.1',
          :compare => '>=',
        }
      },
      {
        :atom => 'app-misc/dummy-3',
        :expected => {
          :package => 'app-misc/dummy',
          :version => '3',
          :compare => '=',
        }
      },
      {
        :atom => '~sys-apps/net-tools-1.60_p20120127084908',
        :expected => {
          :package => 'sys-apps/net-tools',
          :version => '1.60_p20120127084908',
          :compare => '~',
        }
      },
      {
        :atom => '<sys-devel/libtool-2.4-r1',
        :expected => {
          :package => 'sys-devel/libtool',
          :version => '2.4-r1',
          :compare => '<',
        }
      },
      {
        :atom => '>=x11-proto/xproto-7.0.23',
        :expected => {
          :package => 'x11-proto/xproto',
          :version => '7.0.23-r1',
          :compare => '>=',
        }
      },
    ]

    invalid_atoms = [
      'gcc',
      'sys-dev-gcc',
      '=app-admin/eselect-fontconfig',
      '!app-accessibility/brltty-4.3.2-r4',
      '<dev-libs/userspace-rcu4.1.2',
      '>=sys-dev/gcc-alpha4.5.1',
    ]

    invalid_atoms.each do |atom|
      it "should raise an error when parsing #{atom}" do
        expect {
          Puppet::Util::Portage.parse_atom(atom)
        }.to raise_error, Puppet::Util::Portage::AtomError
      end
    end
  end
end
