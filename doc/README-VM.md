# Virtualization Instructions

## VirtualBox 5.2.8

### Pre-Setup

**On host machine**:

- If your computer is low on memory, close all other programs besides
  VirtualBox
- Determine the fastest pacman mirrors for your location

### Setup

**On host machine**:

- Install VirtualBox and VirtualBox Extension Pack from Oracle
  - `brew cask install virtualbox virtualbox-extension-pack`
- Launch VirtualBox
- Change default Machine Folder
  - VirtualBox->Preferences->Default Machine Folder->`~/Documents/vboxen`
- New
  - Name: void64
  - Type: Linux
  - Version: Other Linux (64-bit)
  - Continue
  - Memory Size: 2048 MB
  - Continue
  - Create a virtual hard disk now
  - Create
  - VDI (VirtualBox Disk Image)
  - Continue
  - Dynamically allocated
  - Continue
  - File Size: 16 GB
  - Create
- With *void64* selected in VirtualBox Manager, click *Settings*
  - Storage
    - Click the CD circle with the (+) sign
      - Choose disk
        - Navigate to Void ISO
          - Open
  - Audio
    - Uncheck Enable Audio
  - Click OK
- Enable UEFI (optional)
  - With *void64* selected in VirtualBox Manager, click *Settings*
    - System
      - Check Enable EFI (special OSes only)
    - Click OK
- With *void64* selected in VirtualBox Manager, click *Start*

### Bootstrap Voidvault

- Follow instructions from *Bootstrap Voidvault* section at the bottom
  of this document

### Post-Setup

**On host machine**:

- Configure VirtualBox virtual machine to not use Void ISO
  - Storage
    - Find the Void ISO
      - Right-click
        - Remove Attachment
- With *void64* selected in VirtualBox Manager, click *Start*
- Follow instructions from *Post-Install* section at the bottom of
  this document

### Configure VirtualBox for Host-Guest SSH

#### Configure Port Forwarding

**On host machine**:

- `VBoxManage modifyvm void64 --natpf1 "ssh,tcp,,3022,,22"`

#### Try Host-Guest SSH

**On guest machine**:

- Temporarily amend `/etc/ssh/sshd_config` to allow password
  authentication
  - `vim /etc/ssh/sshd_config`
    - `PasswordAuthentication yes`
- Configure `sshd` runit service to not launch `sshd` on startup
  - `touch /etc/sv/sshd/down`
- Start `sshd`
  - first time: `ln -s /etc/sv/sshd /var/service`
  - subsequent: `sv up sshd`

**On host machine**:

- `sftp -P 3022 variable@127.0.0.1`
  - succeeds
- `ssh -p 3022 variable@127.0.0.1`
  - fails
    - only sftp is allowed

#### Configure SSH Pubkey Authentication for Host-Guest SSH

**On host machine**:

- Create SSH keypair
  - `mkdir ~/.ssh/vbox-void64`
  - `ssh-keygen -t ed25519 -b 521 -f ~/.ssh/vbox-void64/id_ed25519`
- Upload SSH pubkey to guest
  - `sftp -P 3022 variable@127.0.0.1`
    - `put /Users/user/.ssh/vbox-void64/id_ed25519.pub`
    - `quit`

**On guest machine**:

- Stop `sshd`
  - `sv down sshd`
- Disallow password authentication
  - `vim /etc/ssh/sshd_config`
    - `PasswordAuthentication no`
- Add uploaded SSH pubkey to `/etc/ssh/authorized_keys`
  - For fresh key
    - `mv /srv/ssh/jail/variable/id_ed25519.pub /etc/ssh/authorized_keys/variable`
  - For additional key
    - `cat /srv/ssh/jail/variable/id_ed25519.pub >> /etc/ssh/authorized_keys/variable`
- Start `sshd`
  `sv up sshd`

#### Try Passwordless Host-Guest SSH

**On host machine**:

- Try `sftp`
  - `sftp -P 3022 -i ~/.ssh/vbox-void64/id_ed25519 variable@127.0.0.1`
    - succeeds
- Create shortcut in `~/.ssh/config` to make this easier:

```sshconfig
Host vbox-void64
    HostName 127.0.0.1
    Port 3022
    IdentityFile ~/.ssh/vbox-void64/id_ed25519
```

- Try `sftp` with shortcut
  - `sftp variable@vbox-void64`
    - succeeds

### Configure VirtualBox for Increased Resolution

**On guest machine**:

- `vim /etc/default/grub`
  - Depending on host machine resolution
    - Check About This Mac->Displays
    - Either
      - Append `video=1360x768` to `GRUB_CMDLINE_LINUX_DEFAULT`
      - Append `video=1440x900` to `GRUB_CMDLINE_LINUX_DEFAULT`
    - Either
      - `GRUB_GFXMODE="1360x768x24"`
      - `GRUB_GFXMODE="1440x900x24"`
- `grub-mkconfig -o /boot/grub/grub.cfg`
- `shutdown -h now`

**On host machine**:

- Depending on host machine resolution
  - Either
    - `VBoxManage setextradata void64 "CustomVideoMode1" "1360x768x24"`
    - `VBoxManage setextradata void64 "CustomVideoMode1" "1440x900x24"`

## VMWare Fusion 10.1.1

### Pre-Setup

**On host machine**:

- If your computer is low on memory, close all other programs besides
  VMWare Fusion
- Determine the fastest pacman mirrors for your location

### Setup

**On host machine**:

- Install VMWare Fusion
- Launch VMWare Fusion
- Select File->New
- Drag and drop the Void ISO into window from MacOS Finder
- Select Linux->Other Linux 4.x or later kernel 64-bit
- Select Legacy BIOS or UEFI
- Select Customize Settings
  - Processors and Memory
    - 1 processor core
    - Memory: 2048 MB
  - Isolation
    - uncheck Enable Drag and Drop
    - uncheck Enable Copy and Paste
- Press Play

### Bootstrap Voidvault

- Follow instructions from *Bootstrap Voidvault* section at the bottom
  of this document

### Post-Setup

**On host machine**:

- Configure VMWare Fusion virtual machine to not use Void ISO
  - Virtual Machine->Settings->CD/DVD (IDE)
    - Uncheck Connect CD/DVD Drive
- Configure VMWare Fusion virtual machine to pass battery status to guest
  - Virtual Machine->Settings->Advanced
    - Check Pass power status to VM
- Press Play
- Follow instructions from *Post-Install* section at the bottom of
  this document

### Configure VMWare Fusion for Host-Guest SSH

#### Configure Port Forwarding

**On guest machine**:

- Get IP address of VM
  - `ifconfig`
    - Note the `inet-addr`
      - Assume for sake of example it is `192.168.198.10`
- Shut down VM
  - `shutdown now`

**On host machine**:

- Edit `nat.conf`
  - `vim /Library/Preferences/VMware\ Fusion/vmnet8/nat.conf`

```dosini
[incomingtcp]
3022 = 192.168.198.10:22
```

The rest of the instructions are the same as with VirtualBox.

## Bootstrap Voidvault

**On guest machine**:

- Boot Void LiveCD
- Select second option when you see the boot loader screen
  - copy to RAM
- Allow time for the LiveCD to boot up
- Login as user `root`, password: `voidlinux`
- Switch root's shell to Bash
  - `chsh -s /bin/bash`
  - `exit`
- Log back in as user `root`, password: `voidlinux`
- Free up 100MB disk space if necessary
  - `xbps-remove --force-revdeps linux-firmware-network`
- Install pkgs
  - `xbps-install -Sv curl rakudo tmux`
- Launch tmux
  - `tmux`
- Fetch Voidvault sources with Curl:
  - `curl -L -o '#1-#2.#3' https://github.com/atweiden/{voidvault}/archive/{master}.{tar.gz}`
  - `tar xvzf voidvault-master.tar.gz`
  - `cd voidvault-master`
- Run Voidvault
  - `export PERL6LIB=lib`
  - `bin/voidvault --help`
  - `bin/voidvault new`
- Follow the prompts as needed, let Voidvault finish to completion
  - Void ISO 2017.10.07 throws an error at the end
    - `/mnt is busy`...
    - ignore this error
    - do what Voidvault would've done anyway:
      - `umount -R /mnt`
      - `cryptsetup luksClose vault`
- Shutdown the LiveCD
  - `shutdown -h now`

## Post-Install

**On guest machine**:

- Enter vault password
- Login as admin user
  - root login will fail due to `/etc/securetty` config
- Get online
  - `ln -s /etc/sv/dhcpcd /var/service`
- Synchronize time
  - `ln -s /etc/sv/chronyd /var/service`
- Get pkgs
  - `xbps-install -Suv`
  - `xbps-install xtools`
  - `xlocate -S`
- Get dotfiles
  - `git clone https://github.com/atweiden/voidfiles ~/.voidfiles`
  - `cd ~/.voidfiles`
  - `./bootstrap.sh`
  - `./fetch-pgp-keys.sh`

## Configure SFTP Onion Site

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

- Use instructions from section *Configure SSH Pubkey Authentication
  for Host-Guest SSH* to setup pubkey authentication
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

## Configure SSH Port Forwarding

Open a local tunnel to guest machine port 54321 on host machine at
port 12345.

**On guest machine**:

```sh
xbps-install darkhttpd
darkhttpd "$PWD" --addr 127.0.0.1 --port 54321
sv up sshd
```

**On host machine**:

```sh
ssh -N -T -L 12345:127.0.0.1:54321 variable@vbox-void64
```

Open a web browser and visit http://127.0.0.1:12345.

## Create Void ISO

Follow the script:

```sh
# fetch void-mklive sources
git clone https://github.com/void-linux/void-mklive
cd void-mklive

# build sources
make

# switch to root user
sudo su

# fetch dependencies for mklive.sh
# liblz4 must be specified manually as of 2018-08-11
_deps=('liblz4')
xbps-install "${_deps[@]}"

# run mklive.sh with additional pkgs
_pkgs=''
_pkgs+=' cdrtools'
_pkgs+=' cryptsetup'
_pkgs+=' curl'
_pkgs+=' dvd+rw-tools'
_pkgs+=' expect'
_pkgs+=' gptfdisk'
_pkgs+=' rakudo'
_pkgs+=' tmux'
_pkgs+=' vim'
./mklive.sh -p "$_pkgs" -S 250
```

When using the resulting ISO with `voidvault new`, be sure to specify
`void --no-setup new`, since you no longer need to install dependencies
or free up any disk space.
