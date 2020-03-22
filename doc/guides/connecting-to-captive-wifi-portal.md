# Connecting To Captive Wifi Portal

## All Approaches: Partially connect to captive wifi portal

See also: [configure-wireless.md][configure-wireless.md]

This is needed no matter which approach you decide to take later on:

```sh
readonly INTERFACE="wlan0"

# connect to captive wifi portal
wpa_supplicant -B -s -i "$INTERFACE" -c /etc/wpa_supplicant/wpa_supplicant.conf
wpa_cli -i "$INTERFACE"
> add_network
> set_network 0 ssid "SSIDNAME"
> set_network 0 key_mgmt NONE
> enable_network 0
> save_config
> quit

# lease ip from captive wifi portal
dhcpcd "$INTERFACE"
```

Note: `key_mgmt NONE` is only necessary if the captive wifi portal can
be connected to without supplying a password. If a password is required,
supply it via `set_network 0 psk "PASSWORD"` as per usual.

## Approach A: Hijack your own GUI machine's active connection

The hackiest approach.

Caveats: Requires two internet-capable machines. One of them must have
GUI support. Connection can be finnicky.

### Step 1. Fully connect to captive wifi portal via GUI machine

**Note the GUI machine's local IP address**

Later, you will set `ip_addr_spoof` to this value:

Operating System | How to obtain local IP address
---------------- | ----------------------------------------------------
iOS              | Settings->Wi-Fi->ConnectedNetworkName(i)->IP Address
macOS            | `ipconfig getifaddr en0`
Linux            | `ip -o -4 route get 1 \| awk '/src/ {print $7}'`
{[mac][macfiles],[pac][pacfiles],[tty][ttyfiles],[void][voidfiles],[xorg][xorgfiles]}files | `localip`

**Note the GUI machine's MAC address**

Later, you will set `mac_addr_spoof` to this value:

Operating System | How to obtain MAC address
---------------- | -----------------------------------------------
iOS              | Settings->General->About->Wi-Fi Address
macOS            | `ifconfig en0 ether \| tail -n 1 \| awk '{print $2}'`
Linux            | `ip -0 addr show dev $INTERFACE \| awk '/link/ && /ether/ {print \$2}' \| tr '[:upper:]' '[:lower:]'`
{[mac][macfiles],[pac][pacfiles],[tty][ttyfiles],[void][voidfiles],[xorg][xorgfiles]}files | `macaddr`

### Step 2. Hijack GUI machine's active connection

```sh
touch hijack.sh
chmod +x hijack.sh
vim hijack.sh
```

```sh
#!/bin/bash

# e.g. wlan0
readonly interface="$(ip -o -4 route show to default | awk '/dev/ {print $5}')"
# e.g. 192.168.10.1
readonly gateway="$(ip -o -4 route show to default | awk '/via/ {print $3}')"
# e.g. 192.168.10.255
readonly broadcast="$(ip -o -4 addr show dev "$interface" | awk '/brd/ {print $6}')"
# e.g. 192.168.10.151/24
readonly ipmask="$(ip -o -4 addr show dev "$interface" | awk '/inet/ {print $4}')"
# e.g. 24
readonly netmask="$(printf "%s\n" "$ipmask" | cut -d "/" -f 2)"
# e.g. 89:cd:a8:f3:b7:92
readonly mac_addr="$(ip -0 addr show dev "$interface" | awk '/link/ && /ether/ {print $2}' | tr '[:upper:]' '[:lower:]')"
# localip from GUI machine
readonly ip_addr_spoof="192.168.10.115"
# macaddr from GUI machine
readonly mac_addr_spoof="f3:c2:39:10:9e:b2"

restore() {
  ip link set "$interface" down
  ip link set dev "$interface" address "$mac_addr"
  ip link set "$interface" up
  ip addr flush dev "$interface"
  ip addr add "$ipmask" broadcast "$broadcast" dev "$interface"
  ip route add default via "$gateway"
}

spoof() {
  ip link set "$interface" down
  ip link set dev "$interface" address "$mac_addr_spoof"
  ip link set "$interface" up
  ip addr flush dev "$interface"
  ip addr add "$ip_addr_spoof/$netmask" broadcast "$broadcast" dev "$interface"
  ip route add default via "$gateway"
}

spoof
```

```sh
sudo ./hijack.sh
```

Credit: [@systematicat][@systematicat]

### Step 3: Disable GUI machine's wifi

Quickly disable GUI machine's wifi shortly after hijacking its connection.

Needed to prevent the router from undoing your hijacked connection.

Alternatively, attempt overpowering the GUI machine's wifi signal.

## Approach B: Submit captive wifi portal login form interactively

The most straightforward approach.

Caveats: The wifi captive portal login page may need to work with
JavaScript disabled for this approach to succeed. Quality of website
rendering with console-only browsers is very poor compared to their
GUI counterparts.

### Environment Setup

```sh
readonly portal="192.168.3.1:10080/ui/dynamic/guest-login.html"
# e.g. https%3A%2F%2Fwww.apple.com%2Flibrary%2Ftest%2Fsuccess.html
readonly url="$(echo "https://www.apple.com/library/test/success.html" | sed 's#:#%3A#g' | sed 's#/#%2F#g')"
# e.g. 68%3Aec%3Ac5%3Ac1%3Aa3%3A63
readonly mac_addr="$(ip link show "$INTERFACE" | tail -n 1 | awk '{print $2}' | sed 's#:#%3A#g')"
# e.g. 192.168.3.144
readonly ip_addr="$(ip -o -4 route get 1 | awk '/src/ {print $7}')"
```

### Example: [lynx][lynx]

**For Linksys Smart Wi-Fi**

```sh
lynx "${portal}?mac_addr=${mac_addr}&url=${url}&ip_addr=${ip_addr}"
```

### Example: [edbrowse][edbrowse]

**For Linksys Smart Wi-Fi**

```sh
cat >> "$HOME/.ebrc" <<EOF
# disguise edbrowse as IE 9 on Windows 7
agent = Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)
# disable JavaScript on captive wifi portal login page
nojs = ${portal/\/*/}
function+init {
  # turn debug off, don't show status messages from this script
  db0
  # use readline for input
  rl+
  # switch to IE 9 user agent
  ua1
}
function+login {
  b ${portal}?mac_addr=${mac_addr}&url=${url}&ip_addr=${ip_addr}
}
EOF
edbrowse
```

```
# run login function from config
<login
# print page
1,$p
# print page
,p
# print first 10 lines
0z10
# print next 10 lines
z
<CR>
# inspect input form on line 8
8i?
# enter password on line 8
8i=ThePasswordForLinksysSmartWiFiCaptivePortalGoesHere
# press the submit button on line 9
9i*
# refresh browser
rf
```

See the [edbrowse user guide][edbrowse user guide] for form submission
tips.

## Approach C: Submit captive wifi portal login form interactively via reverse proxy

The most universal approach.

Caveats: Requires two internet-capable machines. One of them must have
GUI support.

**On console-only machine**

Configure machine for localhost SSH access:

```sh
# console-only machine sftponly user name
readonly nox_sftponly="sftponly-user"
mkdir -p "$HOME/.ssh/localhost"
ssh-keygen -t ed25519 -b 521 -f "$HOME/.ssh/localhost/id_ed25519"
cat "$HOME/.ssh/localhost/id_ed25519.pub" >> "/etc/ssh/authorized_keys/$nox_sftponly"
```

Setup localhost port forwarding:

```sh
ssh -vvv -N -T -i "$HOME/.ssh/localhost/id_ed25519" -D 9999 "$nox_sftponly@127.0.0.1"
```

Setup reverse port forwarding to GUI machine:

```sh
# GUI machine sftponly user name
readonly gui_sftponly="sftponly-user"

# GUI machine local IP address
readonly gui_localip="192.168.10.150"

# bind GUI machine port 6666 to console-only machine port 9999
# makes your local socks proxy available to GUI machine on port 6666
ssh -vvv -N -T -R 6666:127.0.01:9999 "$gui_sftponly@$gui_localip"
```

Read the `ssh -R` command's verbose log closely. The log should mention
`remote forward success for: listen: 6666, connect: 127.0.0.1:9999`
somewhere near the bottom when you first authenticate with the other
machine. If the log instead warns that the port forwarding has failed,
try again with a different port, e.g.

```sh
ssh -vvv -N -T -R 42345:127.0.01:9999 "$gui_sftponly@$gui_localip"
```

**On GUI machine**

Configure [proxychains][proxychains]:

```sh
# macos: `$(brew --prefix)/etc/proxychains.conf`
cat >> /etc/proxychains.conf <<'EOF'
[ProxyList]
# SSH reverse proxy
socks5 127.0.0.1 6666
EOF
```

Configure GUI machine web browser to use proxy. Submit captive wifi
portal login form with proxified web browser:

```sh
proxychains "$BROWSER"
```

If the above fails:

- Close any open SSH tunnels and stop `sshd` on both machines
- Disconnect both machines from the internet
- Generate and set a new MAC address on both machines
- Go back to initial step *Setup localhost port forwarding*
  - Keep in mind the local IP address of both machines is likely to
    have changed

Credit: [Kaii][Kaii]

## Approach D: Submit captive wifi portal login form interactively via [WireGuard][WireGuard]

The most satisfying approach.

Caveats: Requires two internet-capable machines. One of them must have
GUI support.

Setup WireGuard on client and server per [wireguard.md][wireguard.md].

Ensure both client and server are partially connected to the captive
wifi portal, or in other words, ensure both have a local IP address
leased from the captive wifi's router.

Forward the WireGuard client's traffic to the WireGuard server.

Submit captive wifi portal login form for the server using the client
*or* server machine. Afterwards both machines will be connected to the
internet, although only one will be fully authenticated with the captive
wifi portal.

## Approach E: Submit captive wifi portal login form programmatically

The most powerful approach.

Use a headless browser or programming language to submit captive wifi
portal login form.

Caveats: Requires up front time investment to understand guest login
page and devise a strategy to login programmatically. This could require
a GUI machine. Headless browser software is often x86 only. Headless
browser software considered harmful.

### Example: [Nightmare][Nightmare]

**For Linksys Smart Wi-Fi**

```sh
mkdir linksys && cd linksys
npm install --save nightmare
vim linksys.js
```

Contents of `linksys.js`:

```js
const Nightmare = require('nightmare')
// do not render visible window
const nightmare = Nightmare({ show: false })
// login info
const portal = 'http://192.168.3.1:10080/ui/dynamic/guest-login.html'
const mac_addr = '68%3Aec%3Ac5%3Ac1%3Aa3%3A63'
const url = 'https%3A%2F%2Fwww.apple.com%2Flibrary%2Ftest%2Fsuccess.html'
const ip_addr = '192.168.3.144'
const guest_pass = 'ThePasswordForLinksysSmartWiFiCaptivePortalGoesHere'
// login
nightmare
  .goto(`${portal}?mac_addr=${mac_addr}&url=${url}&ip_addr=${ip_addr}`)
  .type('#guest-pass', `${guest_pass}`)
  .click('#submit-login')
  .evaluate(() => {
    return document.querySelector('body').innerText
  })
  .end()
  .then(body => {
    console.log(body)
  })
  .catch(error => {
    console.error('Error:', error)
  })
```

```sh
node linksys.js
```

### Example: Python

**For Nomadix**

```sh
vim nomadix.py
```

Contents of `nomadix.py`:

```python
#!/usr/bin/python
import urllib
url = "http://login.nomadix.com:1111/usg/process?OS=http://bellevue.house.hyatt.com/en/hotel.home.html"
username = "{whatever}"
password = "{whatever}"
login_data = urllib.urlencode({'username': username, 'password' : password, 'submit': 'loginform2'})
op = urllib.urlopen(url, login_data).read()
print op
```

```sh
python nomadix.py
```

credit: [/r/raspberry_pi][/r/raspberry_pi]

## Notes

Linux `ip` commands require pkg [iproute2][iproute2].

## See Also

- https://github.com/authq/captive-login
- https://github.com/systematicat/hack-captive-portals
- https://github.com/imwally/starbucksconnect


[configure-wireless.md]: configure-wireless.md
[edbrowse]: https://github.com/CMB/edbrowse
[edbrowse user guide]: http://www.edbrowse.org/usersguide.html#input
[Internet sharing]: https://wiki.archlinux.org/index.php/Internet_sharing
[iproute2]: https://wiki.linuxfoundation.org/networking/iproute2
[Kaii]: https://serverfault.com/questions/361794/with-ssh-only-reverse-tunnel-web-access-via-ssh-socks-proxy/361806#361806
[lynx]: https://invisible-island.net/lynx/
[macfiles]: https://github.com/atweiden/macfiles
[Nightmare]: https://www.nightmarejs.org/
[OpenSSH]: https://www.openssh.com/
[pacfiles]: https://github.com/atweiden/pacfiles
[proxychains]: https://github.com/rofl0r/proxychains-ng
[/r/raspberry_pi]: https://www.reddit.com/r/raspberry_pi/comments/4li7za/connecting_to_an_open_hotel_wifi/d3nlfq2/
[ttyfiles]: https://github.com/atweiden/ttyfiles
[voidfiles]: https://github.com/atweiden/voidfiles
[sshuttle]: https://github.com/sshuttle/sshuttle
[sshuttle-reverse-proxy]: https://groups.google.com/forum/#!topic/sshuttle/tWegyCLIBg8
[@systematicat]: https://github.com/systematicat/hack-captive-portals
[WireGuard]: https://www.wireguard.com/
[wireguard.md]: wireguard.md
[xorgfiles]: https://github.com/atweiden/xorgfiles

<!-- vim: set filetype=markdown foldmethod=marker foldlevel=0 nowrap: -->
