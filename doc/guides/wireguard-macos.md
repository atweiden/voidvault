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

Generate keys:

```sh
# make sure credentials don't leak in a race condition
umask 077

# generate keypair
wg genkey | tee privatekey | wg pubkey > publickey
```

Configure WireGuard:

```sh
readonly CLIENT_PRIVATE_KEY="$(cat privatekey)"
readonly SERVER_PUBLIC_KEY="..."
readonly SERVER_IP="..."

# make wireguard config directory
mkdir -p /usr/local/etc/wireguard

# make config file
cat > /usr/local/etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.192.122.2/32
PrivateKey = $CLIENT_PRIVATE_KEY
DNS = 10.192.122.1
# true makes commenting, formatting impossible
SaveConfig = false

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:51820
# gateway rule - send all traffic out over the VPN
AllowedIPs = 0.0.0.0/0, ::/0
# keep stateful firewall or NAT mapping valid every N seconds
#PersistentKeepalive = 25
EOF

chmod 600 /usr/local/etc/wireguard/wg0.conf
```

**On macOS VirtualBox guest**:

Follow server setup instructions in [wireguard.md][wireguard.md].

[wireguard.md]: wireguard.md
