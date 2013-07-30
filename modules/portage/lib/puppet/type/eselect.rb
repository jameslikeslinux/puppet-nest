Puppet::Type.newtype(:eselect) do

  newparam(:name, :isnamevar => true) do
    desc "The name of the eselect module."
  end

  newproperty(:set) do
    desc "The value of the eselect module."
  end
end
