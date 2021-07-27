# Create Void ISO

```sh
# fetch void-mklive sources
git clone https://github.com/void-linux/void-mklive
cd void-mklive

# build sources
make

# switch to root user
sudo su

# fetch dependencies for mklive.sh
# must be specified manually as of 2018-08-17
_deps=('liblz4'
       'squashfs-tools')
xbps-install "${_deps[@]}"

# prepare include directory
git clone https://github.com/atweiden/voidfiles /tmp/include/opt/voidfiles
git clone https://github.com/atweiden/voidpkgs /tmp/include/opt/voidpkgs
git clone https://github.com/atweiden/voidvault /tmp/include/opt/voidvault
git clone https://github.com/systematicat/hack-captive-portals /tmp/include/opt/hack-captive-portals

# copy in etcfiles from voidvault
find /tmp/include/opt/voidvault/resources -mindepth 1 -maxdepth 1 -exec \
  cp -R '{}' /tmp/include \;

# rm shell timeout script on livecd
rm -rf /tmp/include/etc/profile.d

# allow root logins on tty1
sed -i 's/^#\(tty1\)/\1/' /tmp/include/etc/securetty

# prevent services from automatically starting on livecd
_svs=('acpid'
      'adb'
      'darkhttpd'
      'dhcpcd'
      'haveged'
      'rsyncd'
      'sshd'
      'tor'
      'uuidd')
for _sv in ${_svs[@]}; do
  mkdir -p "/tmp/include/etc/sv/$_sv"
  touch "/tmp/include/etc/sv/$_sv/down"
done

# run mklive.sh with additional pkgs
_pkgs=('acpi'
       'android-tools'
       'aria2'
       'base-devel'
       'bash-completion'
       'bootiso'
       'btrfs-progs'
       'bzip2'
       'ccrypt'
       'cdrtools'
       'colordiff'
       'crda'
       'cryptsetup'
       'curl'
       'darkhttpd'
       'dhclient'
       'dhcpcd'
       'dialog'
       'diffr'
       'dnscrypt-proxy'
       'dosfstools'
       'dsvpn'
       'dvd+rw-tools'
       'e2fsprogs'
       'edbrowse'
       'efibootmgr'
       'elixir'
       'enchive'
       'ethtool'
       'expect'
       'fd'
       'fzf'
       'git'
       'gnupg'
       'gptfdisk'
       'grub'
       'gzip'
       'haveged'
       'icdiff'
       'inetutils'
       'iproute2'
       'iputils'
       'iw'
       'jq'
       'just'
       'kpcli'
       'ldns'
       'libimobiledevice'
       'lvm2'
       'lynx'
       'man-pages-posix'
       'mkpasswd'
       'mobile-broadband-provider-info'
       'mosh'
       'ncdu'
       'ncurses-term'
       'net-tools'
       'nftables'
       'nilfs-utils'
       'nmap'
       'nodejs'
       'openresolv'
       'openssh'
       'passphrase2pgp'
       'pinentry'
       'ppp'
       'proxychains-ng'
       'psmisc'
       'pwgen'
       'pwget'
       'qrencode'
       'quixand'
       'rakudo'
       'rclone'
       'ripgrep'
       'rlwrap'
       'rsync'
       'rtorrent'
       'screen'
       'shellcheck'
       'sipcalc'
       'socat'
       'socklog-void'
       'sshuttle'
       'ssss'
       'the_silver_searcher'
       'tmux'
       'toggle-ht'
       'tor'
       'torsocks'
       'tree'
       'vim'
       'wget'
       'wireguard-tools'
       'wireless_tools'
       'wpa_supplicant'
       'wvdial'
       'xtools'
       'zip'
       'zstd')
./mklive.sh -p "'${_pkgs[@]}'" -I /tmp/include
```
