VOIDVAULT(1)

# NAME

voidvault - Bootstrap Void Linux with full disk encryption

# OPTIONS

*--vault-key=<path>*
	Path to LUKS encrypted volume key. Default: */boot/volume.key*

	NOTE: It's strongly recommended to use a path inside */boot*,
	because Voidvault removes _read_, _write_ and _execute_
	permissions there from the _group_ and _other_ classes, leaving
	*root* as the only user able to access the Vault Key.

	1FA and 2FA Mode both provide additional incentive to place
	the Vault Key inside */boot*, because */boot* ("The Bootvault")
	and */* ("The Vault") are encrypted separately in these modes,
	and are located on different partitions and different devices,
	respectively. When this recommendation is followed, these modes
	allow unmounting The Bootvault after the Vault Key placed within
	it successfully unlocks The Vault.
