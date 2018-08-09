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

```sh
#!/bin/bash
declare -A _revdeps=()
for _pkg in "$(xbps-query --list-pkgs | awk '{print $2}')"; do
  _revdeps["$_pkg"]="$(xbps-query --revdeps "$_pkg")"
done
for _i in "${!_revdeps[@]}"; do
  echo "$_i: ${_revdeps[$_i]}"
done
```
