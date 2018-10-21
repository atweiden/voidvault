# Virtualization Instructions

## VirtualBox 5.2.8

### Pre-Setup

**On host machine**:

- If your computer is low on memory, close all other programs besides
  VirtualBox

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
  - `ln -s /etc/sv/sshd /var/service`
  - `sv up sshd`

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

### Configure VirtualBox for Bridged Networking

**On host machine**:

- With *void64* selected in VirtualBox Manager, click *Settings*
  - Network->Adapter 1->Bridged Adapter
- With *void64* selected in VirtualBox Manager, click *Start*

**On guest machine**:

Get connected:

```sh
ip link set <interface> up
dhcpcd <interface>
localip
```

You can now connect to the VirtualBox guest's `localip`, e.g.

```sh
ssh -vvv -N -T -i "$HOME/.ssh/vbox-void64/id_ed25519" -D 9999 variable@192.168.3.121
```

## VMWare Fusion 10.1.1

### Pre-Setup

**On host machine**:

- If your computer is low on memory, close all other programs besides
  VMWare Fusion

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
  - `export PATH="$(realpath bin):$PATH"`
  - `export PERL6LIB="$(realpath lib)"`
  - `voidvault --help`
  - `voidvault new`
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
