# Create Void ISO

```sh
# fetch dependencies for mklive.sh
_deps=('git'
       'liblz4'
       'make'
       'squashfs-tools')
xbps-install "${_deps[@]}"

# fetch void-mklive sources
git clone https://github.com/void-linux/void-mklive
cd void-mklive

# build sources
make

# switch to root user
sudo su

# prepare include directory
git clone https://github.com/atweiden/voidfiles /tmp/include/opt/voidfiles
git clone https://github.com/atweiden/voidpkgs /tmp/include/opt/voidpkgs
git clone https://github.com/atweiden/voidvault /tmp/include/opt/voidvault

# copy in etcfiles from voidvault
find /tmp/include/opt/voidvault/resources -mindepth 1 -maxdepth 1 -exec \
  cp -R '{}' /tmp/include \;

# rm shell timeout script on livecd
rm -rf /tmp/include/etc/profile.d

# allow root logins on tty1
sed -i 's/^#\(tty1\)/\1/' /tmp/include/etc/securetty

# prevent services from automatically starting on livecd
_svs=('acpid'
      'chronyd'
      'darkhttpd'
      'dhcpcd'
      'dnsmasq'
      'haveged'
      'rsyncd'
      'sftpgo'
      'sshd'
      'tor'
      'unbound'
      'uuidd'
      'zramen')
for _sv in ${_svs[@]}; do
  mkdir -p "/tmp/include/etc/sv/$_sv"
  touch "/tmp/include/etc/sv/$_sv/down"
done

# run mklive.sh with additional pkgs
remote="https://ftp.swin.edu.au/voidlinux/current"
XBPS_REPOSITORY="--repository=$remote --repository=$remote/nonfree" ./mklive.sh -p "acpi aerc age aircrack-ng aria2 bandwhich base-devel bash-completion bc bettercap bootiso borg btrfs-progs bzip2 catgirl cdrtools chrony coWPAtty crda create_ap cryptsetup curl darkhttpd dhclient dhcpcd dialog diffr diskonaut dnscrypt-proxy dnsmasq dosfstools dvd+rw-tools e2fsprogs edbrowse efibootmgr elixir enchive ethtool expect fake-hwclock faketime fd firejail fzf git gnupg gnupg1 gptfdisk grub gzip hashcat hashcat-utils haveged hdparm hostapd icdiff inetutils intel-ucode iproute2 iputils iw john jq just ldns libgfshare libgfshare-tools libimobiledevice lua51 lua53 lua54 luarocks-lua51 luarocks-lua53 luarocks-lua54 lvm2 lynx man-pages-posix mobile-broadband-provider-info moreutils mosh ncurses-term net-tools nftables nilfs-utils nodejs nvme-cli nwipe obfs4proxy openresolv openssh orjail outils passphrase2pgp pinentry pinentry-tty procs proxychains-ng psmisc pv pwgen pwget python3 qrencode quixand rakudo rclone ripgrep rlwrap rsync rtorrent scapy screen sftpgo so socat socklog-void sqlite sshuttle sss-cli stegsnow tealdeer tmux toggle-ht tor torsocks tree unbound units unzip vim void-release-keys wget whois wifish wireguard-tools wireless_tools wpa_supplicant xfsprogs xtools zip zramen zstd" -I /tmp/include

# run mklive.sh with additional pkgs plus broadcom-wl-dkms, iwd and patched wpa_supplicant
local="/tmp/include/opt/voidpkgs"
cd "$local"
echo XBPS_MIRROR="$remote" >> etc/conf
./xbps-src binary-bootstrap
sed -i 's/^\(CONFIG_MESH.*\)/#\1/' srcpkgs/wpa_supplicant/files/config
./xbps-src pkg wpa_supplicant
XBPS_REPOSITORY="--repository=$remote --repository=$remote/nonfree" ./mklive.sh -p "acpi aerc age aircrack-ng aria2 bandwhich base-devel bash-completion bc bettercap bootiso borg broadcom-wl-dkms btrfs-progs bzip2 catgirl cdrtools chrony coWPAtty crda create_ap cryptsetup curl darkhttpd dhclient dhcpcd dialog diffr diskonaut dnscrypt-proxy dnsmasq dosfstools dvd+rw-tools e2fsprogs edbrowse efibootmgr elixir enchive ethtool expect fake-hwclock faketime fd firejail fzf git gnupg gnupg1 gptfdisk grub gzip hashcat hashcat-utils haveged hdparm hostapd icdiff inetutils intel-ucode iproute2 iputils iw iwd john jq just ldns libgfshare libgfshare-tools libimobiledevice lua51 lua53 lua54 luarocks-lua51 luarocks-lua53 luarocks-lua54 lvm2 lynx man-pages-posix mobile-broadband-provider-info moreutils mosh ncurses-term net-tools nftables nilfs-utils nodejs nvme-cli nwipe obfs4proxy openresolv openssh orjail outils passphrase2pgp pinentry pinentry-tty procs proxychains-ng psmisc pv pwgen pwget python3 qrencode quixand rakudo rclone ripgrep rlwrap rsync rtorrent scapy screen sftpgo so socat socklog-void sqlite sshuttle sss-cli stegsnow tealdeer tmux toggle-ht tor torsocks tree unbound units unzip vim void-release-keys wget whois wifish wireguard-tools wireless_tools wpa_supplicant xfsprogs xtools zip zramen zstd" -I /tmp/include -r "$local/hostdir/binpkgs"

# run mklive.sh with additional pkgs plus restricted package
cd "$local"
./xbps-src binary-bootstrap
echo XBPS_ALLOW_RESTRICTED="yes" >> etc/conf
./xbps-src pkg b43-firmware
XBPS_REPOSITORY="--repository=$remote --repository=$remote/nonfree" ./mklive.sh -p "acpi aerc age aircrack-ng aria2 b43-firmware bandwhich base-devel bash-completion bc bettercap bootiso borg btrfs-progs bzip2 catgirl cdrtools chrony coWPAtty crda create_ap cryptsetup curl darkhttpd dhclient dhcpcd dialog diffr diskonaut dnscrypt-proxy dnsmasq dosfstools dvd+rw-tools e2fsprogs edbrowse efibootmgr elixir enchive ethtool expect fake-hwclock faketime fd firejail fzf git gnupg gnupg1 gptfdisk grub gzip hashcat hashcat-utils haveged hdparm hostapd icdiff inetutils intel-ucode iproute2 iputils iw john jq just ldns libgfshare libgfshare-tools libimobiledevice lua51 lua53 lua54 luarocks-lua51 luarocks-lua53 luarocks-lua54 lvm2 lynx man-pages-posix mobile-broadband-provider-info moreutils mosh ncurses-term net-tools nftables nilfs-utils nodejs nvme-cli nwipe obfs4proxy openresolv openssh orjail outils passphrase2pgp pinentry pinentry-tty procs proxychains-ng psmisc pv pwgen pwget python3 qrencode quixand rakudo rclone ripgrep rlwrap rsync rtorrent scapy screen sftpgo so socat socklog-void sqlite sshuttle sss-cli stegsnow tealdeer tmux toggle-ht tor torsocks tree unbound units unzip vim void-release-keys wget whois wifish wireguard-tools wireless_tools wpa_supplicant xfsprogs xtools zip zramen zstd" -I /tmp/include -r "$local/hostdir/binpkgs/nonfree"
```
