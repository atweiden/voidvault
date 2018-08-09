install
-------

- boot livecd
- select second option
  - copy to RAM
- login as root:voidlinux
- switch to bash
  - `/bin/bash`
- free up 100MB disk space
  - `xbps-remove --force-revdeps linux-firmware-network`
- install pkgs
  - `xbps-install -Sv curl rakudo tmux`
- switch on tmux
  - `tmux`
- fetch voidvault
  - `curl -L -o '#1-#2.#3' https://github.com/atweiden/{voidvault}/archive/{master}.{tar.gz}`
  - `tar xvzf voidvault-master.tar.gz`
  - `cd voidvault-master`

post-install
------------

get online:

```sh
sudo su
chsh -s /bin/bash
ln -s /etc/sv/dhcpcd /etc/runit/runsvdir/default/dhcpcd
```

sync time:

```sh
ln -s /etc/sv/chronyd /etc/runit/runsvdir/default/chronyd
```

update system pkgs:

```sh
xbps-install -Suv
```

switch back to normal user

```sh
exit
```

get voidfiles:

```sh
git clone https://github.com/atweiden/voidfiles ~/.voidfiles
cd ~/.voidfiles
./bootstrap.sh
```

get more pkgs:

```
xbps-install xtools
xlocate -S
```
