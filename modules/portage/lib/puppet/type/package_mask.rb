require 'puppet/util/portage'
Puppet::Type.newtype(:package_mask) do
  @doc = "Mask packages in portage.

      package_mask { 'app-admin/chef':
        target  => 'chef',
      }"

  ensurable do
    defaultvalues
    defaultto :present
  end

  newparam(:name) do
    desc "The package name"

    isnamevar

    validate do |value|

      unless Puppet::Util::Portage.valid_package? value
        raise ArgumentError, "name must be a properly formatted atom, see portage(5) for more information"
      end
    end
  end

  newproperty(:version) do
    desc "A properly formatted version string"

    validate do |value|
      unless Puppet::Util::Portage.valid_version? value
        raise ArgumentError, "name must be a properly formatted version"
      end
    end
  end

  newproperty(:target) do
    desc "The location of the package.mask file"

    defaultto do
      if @resource.class.defaultprovider.ancestors.include?(Puppet::Provider::ParsedFile)
        @resource.class.defaultprovider.default_target
      else
        nil
      end
    end

    # Allow us to not have to specify an absolute path unless we really want to
    munge do |value|
      if !value.match(/\//)
        value = "/etc/portage/package.mask/" + value
      end
      value
    end
  end
end
