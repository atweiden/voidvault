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

# run mklive.sh with additional pkgs
_pkgs=''
_pkgs+=' acpi'
_pkgs+=' bash-completion'
_pkgs+=' binutils'
_pkgs+=' btrfs-progs'
_pkgs+=' bzip2'
_pkgs+=' cdrtools'
_pkgs+=' crda'
_pkgs+=' cryptsetup'
_pkgs+=' curl'
_pkgs+=' dhclient'
_pkgs+=' dialog'
_pkgs+=' dosfstools'
_pkgs+=' dvd+rw-tools'
_pkgs+=' e2fsprogs'
_pkgs+=' efibootmgr'
_pkgs+=' ethtool'
_pkgs+=' expect'
_pkgs+=' git'
_pkgs+=' gnupg2'
_pkgs+=' gptfdisk'
_pkgs+=' grub'
_pkgs+=' gzip'
_pkgs+=' haveged'
_pkgs+=' inetutils'
_pkgs+=' iproute2'
_pkgs+=' iputils'
_pkgs+=' iw'
_pkgs+=' ldns'
_pkgs+=' lynx'
_pkgs+=' net-tools'
_pkgs+=' nftables'
_pkgs+=' openssh'
_pkgs+=' pinentry'
_pkgs+=' psmisc'
_pkgs+=' rakudo'
_pkgs+=' rsync'
_pkgs+=' socat'
_pkgs+=' tar'
_pkgs+=' tmux'
_pkgs+=' tor'
_pkgs+=' unzip'
_pkgs+=' vim'
_pkgs+=' wireless_tools'
_pkgs+=' wpa_actiond'
_pkgs+=' wpa_supplicant'
_pkgs+=' xz'
_pkgs+=' zip'
_pkgs+=' zstd'
./mklive.sh -p "$_pkgs" -S 250
```

When using the resulting ISO with `voidvault new`, be sure to specify
`voidvault --no-setup new`, since you no longer need to install
dependencies or free up any disk space.
