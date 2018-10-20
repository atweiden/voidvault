# WireGuard

## Configure

**On the client**:

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

# make config file
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
# virtual ip address, with subnet mask for vpn
Address = 10.192.122.2/32
PrivateKey = $CLIENT_PRIVATE_KEY
DNS = 10.192.122.1
# true makes commenting, formatting impossible
SaveConfig = false

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:51820
# gateway rule - send all traffic out over the vpn
AllowedIPs = 0.0.0.0/0, ::/0
# keep stateful firewall or nat mapping valid every n seconds
#PersistentKeepalive = 25
EOF

chmod 600 /etc/wireguard/wg0.conf
```

**On the server**:

Generate keys:

```sh
# make sure credentials don't leak in a race condition
umask 077

# generate keypair
wg genkey | tee privatekey | wg pubkey > publickey
```

Configure WireGuard:

```sh
readonly CLIENT_PUBLIC_KEY="..."
readonly SERVER_PRIVATE_KEY="$(cat privatekey)"

# make config file
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
# virtual ip address, with subnet mask for vpn
Address = 10.192.122.1/24
ListenPort = 51820
PrivateKey = $SERVER_PRIVATE_KEY
# true makes commenting, formatting impossible
SaveConfig = false
# load kernel modules
PostUp = modprobe nft_masq
PostUp = modprobe nft_masq_ipv4
PostUp = modprobe nft_masq_ipv6
PostUp = modprobe nft_nat
PostUp = modprobe nft_chain_nat_ipv4
PostUp = modprobe nft_chain_nat_ipv6
# configure kernel parameters
PostUp = sysctl --write net.ipv4.ip_forward=1
PostUp = sysctl --write net.ipv4.conf.all.forwarding=1
PostUp = sysctl --write net.ipv4.conf.default.forwarding=1
PostUp = sysctl --write net.ipv6.conf.all.forwarding=1
PostUp = sysctl --write net.ipv6.conf.default.forwarding=1
PostUp = sysctl --write net.ipv4.conf.all.proxy_arp=1
PostUp = sysctl --write net.ipv4.conf.default.proxy_arp=1
PostUp = sysctl --write net.ipv6.conf.all.proxy_ndp=1
PostUp = sysctl --write net.ipv6.conf.default.proxy_ndp=1
PostUp = sysctl --write net.ipv4.ip_dynaddr=7
# activate nftables includes for wireguard
PostUp = mkdir --parents /etc/nftables/includes/table/inet/filter/forward
PostUp = mkdir --parents /etc/nftables/includes/table/inet/filter/input
PostUp = ln --symbolic --force /etc/nftables/wireguard/table/wireguard.nft /etc/nftables/includes/table
PostUp = ln --symbolic --force /etc/nftables/wireguard/table/inet/filter/forward/wireguard.nft /etc/nftables/includes/table/inet/filter/forward
PostUp = ln --symbolic --force /etc/nftables/wireguard/table/inet/filter/input/wireguard.nft /etc/nftables/includes/table/inet/filter/input
# reload nftables with includes for wireguard
PostUp = nft --file /etc/nftables.conf
# make dnscrypt-proxy listen on wireguard interface
PostUp = sed -i -e "/^listen_addresses/s/\(.*\)/#\1/" -e "/^#listen_addresses/p" -e "s/^#\(listen_addresses = \[.*\)\]/\1, '10.192.122.1:53']/" /etc/dnscrypt-proxy.toml
PostUp = sv restart dnscrypt-proxy
# deactivate nftables includes for wireguard
PostDown = rm --force /etc/nftables/includes/table/wireguard.nft
PostDown = rm --force /etc/nftables/includes/table/inet/filter/forward/wireguard.nft
PostDown = rm --force /etc/nftables/includes/table/inet/filter/input/wireguard.nft
PostDown = rmdir --ignore-fail-on-non-empty --parents /etc/nftables/includes/table/inet/filter/forward
PostDown = rmdir --ignore-fail-on-non-empty --parents /etc/nftables/includes/table/inet/filter/input
# reload nftables without includes for wireguard
PostDown = nft --file /etc/nftables.conf
# unload kernel modules
PostDown = rmmod nft_masq_ipv4
PostDown = rmmod nft_masq_ipv6
PostDown = rmmod nft_masq
PostDown = rmmod nft_chain_nat_ipv4
PostDown = rmmod nft_chain_nat_ipv6
PostDown = rmmod nft_nat
# reconfigure kernel parameters
PostDown = sysctl --write net.ipv4.ip_forward=0
PostDown = sysctl --write net.ipv4.conf.all.forwarding=0
PostDown = sysctl --write net.ipv4.conf.default.forwarding=0
PostDown = sysctl --write net.ipv6.conf.all.forwarding=0
PostDown = sysctl --write net.ipv6.conf.default.forwarding=0
PostDown = sysctl --write net.ipv4.conf.all.proxy_arp=0
PostDown = sysctl --write net.ipv4.conf.default.proxy_arp=0
PostDown = sysctl --write net.ipv6.conf.all.proxy_ndp=0
PostDown = sysctl --write net.ipv6.conf.default.proxy_ndp=0
PostDown = sysctl --write net.ipv4.ip_dynaddr=0
# make dnscrypt-proxy not listen on wireguard interface
PostDown = sed -i -e "/^listen_addresses/d" -e "/^#listen_addresses/s/^#\(.*\)/\1/" /etc/dnscrypt-proxy.toml
PostDown = sv restart dnscrypt-proxy

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
# identical to client's interface address, using same subnet mask
AllowedIPs = 10.192.122.2/32
EOF

chmod 600 /etc/wireguard/wg0.conf
```

## Execute

**On the server**:

Bring up WireGuard:

```sh
wg-quick up wg0
```

Check to make sure dnscrypt-proxy is listening on WireGuard interface:

```sh
netstat -tulpn
```

**On the client**:

```sh
wg-quick up wg0
```

<!-- vim: set filetype=markdown foldmethod=marker foldlevel=0 nowrap -->
