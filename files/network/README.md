# systemd-networkd configuration

Each of these files represents either a specific configuration (level 10),
broad configuration (level 20), or generic configuration (level 30). Less
specific configurations can be overridden by a file with a more specific match.
Overrides and additions can be proccessed through drop-ins, but additional
matches cannot be added except by overriding the generic config.
