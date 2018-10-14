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
cat > /etc/wireguard/wg0.conf <<"EOF"
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
# uncomment PersistentKeepalive if client is behind NAT
#PersistentKeepalive = 25
EOF
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
# change this to primary internet-connected interface
readonly INTERFACE="eth0"
readonly CLIENT_PUBLIC_KEY="..."
readonly SERVER_PRIVATE_KEY="$(cat privatekey)"

# make config file
cat > /etc/wireguard/wg0.conf <<"EOF"
[Interface]
# the virtual IP address, with the subnet mask we will use for the VPN
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
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = sysctl -w net.ipv4.conf.all.forwarding=1
PostUp = sysctl -w net.ipv4.conf.default.forwarding=1
PostUp = sysctl -w net.ipv6.conf.all.forwarding=1
PostUp = sysctl -w net.ipv6.conf.default.forwarding=1
PostUp = sysctl -w net.ipv4.conf.all.proxy_arp=1
PostUp = sysctl -w net.ipv4.conf.default.proxy_arp=1
PostUp = sysctl -w net.ipv6.conf.all.proxy_ndp=1
PostUp = sysctl -w net.ipv6.conf.default.proxy_ndp=1
PostUp = sysctl -w net.ipv4.ip_dynaddr=7
# add prerequisite for nftables NAT
PostUp = nft add table ip nox-wg-nat
PostUp = nft add chain ip nox-wg-nat prerouting { type nat hook prerouting priority 0\; }
PostUp = nft add rule ip nox-wg-nat prerouting counter comment \"count accepted packets\"
PostUp = nft add rule ip nox-wg-nat prerouting counter log prefix \"nft#nox-wg-nat: \"
PostUp = nft add chain ip nox-wg-nat input { type nat hook input priority 100\; }
PostUp = nft add rule ip nox-wg-nat input counter comment \"count accepted packets\"
PostUp = nft add rule ip nox-wg-nat input counter log prefix \"nft#nox-wg-nat: \"
PostUp = nft add chain ip nox-wg-nat output { type nat hook output priority 0\; }
PostUp = nft add rule ip nox-wg-nat output counter comment \"count accepted packets\"
PostUp = nft add rule ip nox-wg-nat output counter log prefix \"nft#nox-wg-nat: \"
PostUp = nft add chain ip nox-wg-nat postrouting { type nat hook postrouting priority 100\; }
PostUp = nft add rule ip nox-wg-nat postrouting counter comment \"count accepted packets\"
PostUp = nft add rule ip nox-wg-nat postrouting counter log prefix \"nft#nox-wg-nat: \"
PostUp = nft add table ip6 nox-wg-nat6
PostUp = nft add chain ip6 nox-wg-nat6 prerouting { type nat hook prerouting priority 0\; }
PostUp = nft add rule ip6 nox-wg-nat6 prerouting counter comment \"count accepted packets\"
PostUp = nft add rule ip6 nox-wg-nat6 prerouting counter log prefix \"nft#nox-wg-nat6: \"
PostUp = nft add chain ip6 nox-wg-nat6 input { type nat hook input priority 100\; }
PostUp = nft add rule ip6 nox-wg-nat6 input counter comment \"count accepted packets\"
PostUp = nft add rule ip6 nox-wg-nat6 input counter log prefix \"nft#nox-wg-nat6: \"
PostUp = nft add chain ip6 nox-wg-nat6 output { type nat hook output priority 0\; }
PostUp = nft add rule ip6 nox-wg-nat6 output counter comment \"count accepted packets\"
PostUp = nft add rule ip6 nox-wg-nat6 output counter log prefix \"nft#nox-wg-nat6: \"
PostUp = nft add chain ip6 nox-wg-nat6 postrouting { type nat hook postrouting priority 100\; }
PostUp = nft add rule ip6 nox-wg-nat6 postrouting counter comment \"count accepted packets\"
PostUp = nft add rule ip6 nox-wg-nat6 postrouting counter log prefix \"nft#nox-wg-nat6: \"
# accept UDP on port 51820 for incoming WireGuard connections
PostUp = nft add table inet nox-wg-inet
PostUp = nft add chain inet nox-wg-inet input
PostUp = nft add rule inet nox-wg-inet input udp dport 51820 accept
# redirect incoming DNS queries to local dnscrypt-proxy
PostUp = nft add rule ip nox-wg-nat prerouting iifname wg0 tcp dport 53 counter dnat to 127.0.0.1:53
PostUp = nft add rule ip nox-wg-nat prerouting iifname wg0 udp dport 53 counter dnat to 127.0.0.1:53
PostUp = nft add rule ip6 nox-wg-nat6 prerouting iifname wg0 tcp dport 53 counter dnat to [::1]:53
PostUp = nft add rule ip6 nox-wg-nat6 prerouting iifname wg0 udp dport 53 counter dnat to [::1]:53
# accept packets from VPN interface for packets being routed through box
PostUp = nft add chain inet nox-wg-inet forward
PostUp = nft add rule inet nox-wg-inet forward iifname wg0 counter accept
# alter outgoing packets to have server IP address
PostUp = nft add rule ip nox-wg-nat postrouting oifname "$INTERFACE" counter masquerade random,persistent
PostUp = nft add rule ip6 nox-wg-nat6 postrouting oifname "$INTERFACE" counter masquerade random,persistent
PostDown = nft flush table inet nox-wg-inet
PostDown = nft delete table inet nox-wg-inet
PostDown = nft flush table ip nox-wg-nat
PostDown = nft delete table ip nox-wg-nat
PostDown = nft flush table ip6 nox-wg-nat6
PostDown = nft delete table ip6 nox-wg-nat6
PostDown = rmmod nft_masq
PostDown = rmmod nft_masq_ipv4
PostDown = rmmod nft_masq_ipv6
PostDown = rmmod nft_nat
PostDown = rmmod nft_chain_nat_ipv4
PostDown = rmmod nft_chain_nat_ipv6
PostDown = sysctl -w net.ipv4.ip_forward=0
PostDown = sysctl -w net.ipv4.conf.all.forwarding=0
PostDown = sysctl -w net.ipv4.conf.default.forwarding=0
PostDown = sysctl -w net.ipv6.conf.all.forwarding=0
PostDown = sysctl -w net.ipv6.conf.default.forwarding=0
PostDown = sysctl -w net.ipv4.conf.all.proxy_arp=0
PostDown = sysctl -w net.ipv4.conf.default.proxy_arp=0
PostDown = sysctl -w net.ipv6.conf.all.proxy_ndp=0
PostDown = sysctl -w net.ipv6.conf.default.proxy_ndp=0
PostDown = sysctl -w net.ipv4.ip_dynaddr=0

[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
# the client's IP with a /32; each client only has one IP
# identical to client's interface address, using same subnet mask
AllowedIPs = 10.192.122.2/32
EOF
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
