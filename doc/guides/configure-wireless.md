# Configure Wireless

## Bringing up the wireless interface

Find the right wireless interface:

```sh
ip link
```

Let's assume it's `wlan0`.

Bring up the wireless interface:

```sh
ip link set wlan0 up
```

## Connecting with `wpa_passphrase`

```sh
wpa_passphrase "myssid" "passphrase" > /etc/wpa_supplicant/myssid-wlan0.conf
cp -R /etc/sv/wpa_supplicant /etc/sv/wpa_supplicant-myssid-wlan0
cat >> /etc/sv/wpa_supplicant-myssid-wlan0/conf <<'EOF'
SSID=myssid
WPA_INTERFACE=wlan0
CONF_FILE="/etc/wpa_supplicant/$SSID-$WPA_INTERFACE.conf"
EOF
touch /etc/sv/wpa_supplicant-myssid-wlan0/down
ln -s /etc/sv/wpa_supplicant-myssid-wlan0 /var/service
sv up wpa_supplicant-myssid-wlan0
```

or:

```sh
wpa_supplicant -B -s -i wlan0 [-Dnl80211,wext] -c <(wpa_passphrase "myssid" "passphrase")
```

If the passphrase contains special characters, rather than escaping them,
invoke `wpa_passphrase` without specifying the passphrase.

## Connecting with `wpa_cli`

Configure `wpa_supplicant` for use with `wpa_cli`:

```sh
cat >> /etc/wpa_supplicant/wpa_supplicant.conf <<'EOF'
# give configuration update rights to wpa_cli
ctrl_interface=/run/wpa_supplicant
ctrl_interface_group=wheel
update_config=1

# enable AP scanning
ap_scan=1

# EAPOL v2 provides better security, but use v1 for wider compatibility
eapol_version=1

# enable fast re-authentication (EAP-TLS session resumption) if supported
fast_reauth=1
EOF
```

Run `wpa_supplicant`:

```sh
cp -R /etc/sv/wpa_supplicant /etc/sv/wpa_supplicant-wlan0
cat >> /etc/sv/wpa_supplicant-wlan0/conf <<'EOF'
WPA_INTERFACE=wlan0
EOF
touch /etc/sv/wpa_supplicant-wlan0/down
ln -s /etc/sv/wpa_supplicant-wlan0 /var/service
sv up wpa_supplicant-wlan0
```

or:

```sh
wpa_supplicant -B -s -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf
```

Run `wpa_cli`:

```sh
wpa_cli
```

Use the `scan` and `scan_results` commands to see the available networks:

```
> scan
OK
<3>CTRL-EVENT-SCAN-RESULTS
> scan_results
bssid / frequency / signal level / flags / ssid
00:00:00:00:00:00 2462 -49 [WPA2-PSK-CCMP][ESS] myssid
11:11:11:11:11:11 2437 -64 [WPA2-PSK-CCMP][ESS] ANOTHERSSID
```

To associate with `myssid`, add the network, set the credentials and
enable it:

```
> add_network
0
> set_network 0 ssid "myssid"
> set_network 0 psk "passphrase"
> enable_network 0
<2>CTRL-EVENT-CONNECTED - Connection to 00:00:00:00:00:00 completed (reauth) [id=0 id_str=]
```

If the SSID does not have password authentication, you must explicitly
configure the network as keyless by replacing the command:

```
> set_network 0 psk "passphrase"
```

with:

```
> set_network 0 key_mgmt NONE
```

Save this network:

```
> save_config
OK
```

## Obtaining an IP address

### using `dhclient`:

```sh
cat >> /etc/sv/dhclient-wlan0/conf <<'EOF'
# run in foreground
OPTS+=' -d'
# only try obtaining IP address lease once
OPTS+=' -1'
EOF

touch /etc/sv/dhclient-wlan0/down
ln -s /etc/sv/dhclient-wlan0 /var/service
sv up dhclient-wlan0
```

### using `dhcpcd`:

```sh
cp -R /etc/sv/dhcpcd-eth0 /etc/sv/dhcpcd-wlan0
sed -i 's/eth0/wlan0/' /etc/sv/dhcpcd-wlan0/run
touch /etc/sv/dhcpcd-wlan0/down
ln -s /etc/sv/dhcpcd-wlan0 /var/service
sv up dhcpcd-wlan0
```
