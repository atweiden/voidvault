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

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
# identical to client's interface address, using same subnet mask
AllowedIPs = 10.192.122.2/32
EOF

chmod 600 /etc/wireguard/wg0.conf
```

## Execute

**On the server**:

```sh
wg-quick up wg0
```

**On the client**:

```sh
wg-quick up wg0
```

## Resources

### WireGuard

- `man wg-quick`
- https://wiki.archlinux.org/index.php/WireGuard
- http://jrs-s.net/2018/08/05/some-notes-on-wireguard/
- http://jrs-s.net/2018/08/05/working-vpn-gateway-configs-for-wireguard/
- http://jrs-s.net/2018/08/05/routing-between-wg-interfaces-with-wireguard/
- https://nbsoftsolutions.com/blog/wireguard-vpn-walkthrough
- https://github.com/mrash/Wireguard-macOS-LinuxVM
- https://www.stavros.io/posts/how-to-configure-wireguard/
- https://www.reddit.com/r/linux/comments/9bnowo/wireguard_benchmark_between_two_servers_with_10/
- https://www.ericlight.com/wireguard-part-one-installation.html
- https://www.ericlight.com/wireguard-part-two-vpn-routing.html

### nftables

- https://wiki.archlinux.org/index.php/nftables
- https://www.funtoo.org/Package:Nftables
- https://www.osdefsec.com/new-iptables-nftables/
- https://home.regit.org/netfilter-en/nftables-quick-howto/
- https://linux-audit.com/nftables-beginners-guide-to-traffic-filtering/
- https://github.com/newfivefour/BlogPosts/blob/master/nftables-basic-rules-save-established.md
- https://paulgorman.org/technical/linux-nftables.txt.html
- https://stosb.com/blog/explaining-my-configs-nftables/
- https://wiki.nftables.org/wiki-nftables/index.php/Simple_rule_management
- http://wiki.nftables.org/wiki-nftables/index.php/Performing_Network_Address_Translation_%28NAT%29
- https://marc.info/?l=netfilter&m=152532769025083&w=2
- https://gist.github.com/mortn/0624297e966a0a2be9a992ee8f77d68b

### DNS

- https://askubuntu.com/questions/592042/iptables-redirect-dns-queries#592398
- https://unix.stackexchange.com/questions/144482/iptables-to-redirect-dns-lookup-ip-and-port
- https://wiki.archlinux.org/index.php/Dnscrypt-proxy#Local_DNS_cache_configuration
- https://gist.github.com/ahmozkya/8456503#file-dnsmasq-conf
- https://jeanbruenn.info/2017/05/09/connection-tracking-and-udp-dns-with-nftables/
- https://jeanbruenn.info/2017/04/30/conntrack-and-udp-dns-with-iptables/
