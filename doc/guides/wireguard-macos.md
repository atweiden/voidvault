# WireGuard on MacOS

**On macOS host**:

Configure VirtualBox guest to use Bridged Networking.

- VirtualBox->Settings->Network->Adapter 1->Bridged Adapter

Boot VirtualBox guest.

**On macOS VirtualBox guest**:

Get connected:

```sh
ip link set <interface> up
dhcpcd <interface>
localip
```

**On macOS host**:

You can now connect to macOS VirtualBox guest's `localip`, e.g.

```sh
ssh -N -T -i "$HOME/.ssh/vbox-void64/id_ed25519" -D 9999 -vvv variable@192.168.3.121
```

**On macOS VirtualBox guest**:

Follow server setup instructions in [wireguard.md][wireguard.md].

[wireguard.md]: wireguard.md
