# systemd-networkd configuration

Each of these files represents either a specific configuration (level 10) or
generic configuration (level 20). Generic configurations can be overridden by a
file with a more specific match. Overrides and additions can be proccessed
through drop-ins, but additional matches cannot be added except by overriding
the generic config.
