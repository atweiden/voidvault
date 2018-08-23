# Configure SFTP Onion Site

**On guest machine**:

- Install `tor`

```sh
xbps-install tor
```

- Configure `tor`

```sh
cat >> /etc/tor/torrc <<'EOF'
RunAsDaemon 0
HiddenServiceDir /var/lib/tor/sftp
HiddenServicePort 9449 127.0.0.1:22
HiddenServiceVersion 3
EOF
```

- Create hidden service directory with locked down permissions

```sh
mkdir /var/lib/tor/sftp
chown -R tor:tor /var/lib/tor/sftp
chmod 700 /var/lib/tor/sftp
```

- Configure tor runit service to use `/etc/tor/torrc`

```
cat >> /etc/sv/tor/run <<'EOF'
#!/bin/sh
exec tor -f /etc/tor/torrc --quiet --runasdaemon 0 2>&1
EOF
```

- Configure tor runit service to not launch on startup

```
touch /etc/sv/tor/down
```

- Retrieve onion site hostname

```sh
ln -s /etc/sv/tor /var/service
sv up tor
sv down tor
cat /var/lib/tor/sftp/hostname
```

- Let's assume the onion site's hostname is
  `brcyqkxmqaun2allfdqxxc6bno37smoi3ealpmkm2f3warulpge5s2id.onion`

**On host machine**:

- Install `openssh`, `socat` and `tor` (or *Tor Browser Bundle*)

```sh
# void
xbps-install openssh socat tor

# mac
brew install openssh socat tor
```

- Use instructions from section ["Configure SSH Pubkey Authentication
  for Host-Guest SSH"][pubkey-auth] to setup pubkey authentication
- Configure ssh for use with `tor`
  - Set `socksport=9150` if running Tor Browser Bundle

```sshconfig
Host vbox-void64-onion
    HostName brcyqkxmqaun2allfdqxxc6bno37smoi3ealpmkm2f3warulpge5s2id.onion
    Port 9449
    PubkeyAuthentication yes
    IdentityFile ~/.ssh/vbox-void64/id_ed25519
    Compression yes
    ProxyCommand socat STDIO SOCKS4A:localhost:%h:%p,socksport=9050
```

**On guest machine**:

- Start `sshd` and `tor`:

```sh
sv up sshd
sv up tor
```

**On host machine**:

- Start `tor` or Tor Browser Bundle
- Try `sftp` with shortcut
  - `sftp variable@vbox-void64-onion`
    - succeeds


[pubkey-auth]: ../README-VM.md#configure-ssh-pubkey-authentication-for-host-guest-ssh
