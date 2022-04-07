VOIDVAULT(1)

# NAME

voidvault - Bootstrap Void Linux with full disk encryption

# OPTIONS

*--vault-key=<path>*
	Path to LUKS encrypted volume key. Default: */boot/keys/root.key*

	Path must be absolute, and point to a location within */boot*.

	NOTE: Voidvault removes _read_, _write_ and _execute_ permissions
	from the _group_ and _other_ classes for */boot*, leaving *root*
	as the only user able to access The Vault Key.

	1FA and 2FA Mode both provide additional incentive to place
	The Vault Key inside */boot*, because */boot* ("The Bootvault")
	and */* ("The Vault") are encrypted separately in these modes,
	and are located on different partitions and different devices,
	respectively. These modes allow unmounting The Bootvault after
	The Vault Key placed within it successfully unlocks The Vault.
