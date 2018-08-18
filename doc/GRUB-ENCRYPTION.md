About GRUB2.0 Encryption
========================

A conversation with rcf on #archlinux irc

```
atweiden-air: cc: grazzolini
atweiden-air: my machines have /boot encryption, GRUB asks for a password
              immediately on bootup
atweiden-air: is it possible to use something like mkinitcpio-tinyssh
              to remotely decrypt /boot in addition to root, or do i
              need to disable GRUB /boot encryption?
         rcf: atweiden-air: that would be rather difficult because the
              initramfs is on the encrypted /boot.
         rcf: atweiden-air: if GRUB has its own SSH server (which I
              doubt, but really wouldn't be surprised if I'm wrong all
              the same because GRUB) you could pull that off.
         rcf: atweiden-air: if you're a bit insane, and have a serial
              port on the motherboard, you can bypass this by using an
              SBC as a terminal server to easily talk to GRUB (configured
              according to https://www.gnu.org/software/grub/manual/grub/html_node/Serial-terminal.html)
      phrik@: Title:GNU GRUB Manual 2.02: Serial terminal (at www.gnu.org)
         rcf: Or hang a microcontroller off the SBC that pretends to be
              a USB keyboard to allow you to enter your password.
     Hello71: what's the point of encrypting /boot anyways
    gehidore: prevent tampering... but physical access is still physical
              access
         rcf: In theory, you prevent an attacker from putting a backdoor
              in your kernel/early userspace if they gain physical access
              to a powered-off machine but aren't trying to steal it. Or
              (since we're already assuming they aren't just going to
              steal it) selecting exploits to be used on the running
              system later on according to the initramfs and kernel.
         rcf: In practice, this is all meaningless without firmware
              support for code signing, because anyone capable of doing
              that effectively is going to have no problem tampering
              with the bootloader instead.
   SyfiMalik: rcf: isn't secure boot with my own keys enough in this
              scenario?
         rcf: SyfiMalik: yes, that's exactly what you'd want. It's
              possible to get around even that if someone is really
              determined, but at that stage you're either being
              investigated by the police, or need to report whoever is
              obsessively stalking you and your computers to the police.
atweiden-air: rcf: "so you're telling me there's a chance!"
atweiden-air: good to know linuxboot and other secure boot opts will
              make grub /boot encryption more complete
atweiden-air: rcf: just curious, what bootloader do you recommend
              replacing grub with. not sure i see much point in sticking
              with grub if not for /boot encryption
         rcf: atweiden-air: if you already have GRUB configured to your
              liking, I'd just keep using it. From my experience the
              only thing I can really tell you is that syslinux isn't
              particularly useful on UEFI.
atweiden-air: rcf: i've seen shade get thrown at grub /boot encryption
              online over "something something expands the attack
              surface". is there any merit to that argument?
         rcf: atweiden-air: they're basically calling grub too bloated
              to effectively audit.
         rcf: atweiden-air: keep in mind that your proposal to enter your
              password over SSH would have expanded the attack surface
              orders of magnitude more than even the most ridiculous
              grub setup, by adding a full network stack.
         rcf: atweiden-air: which does remind me that you can accomplish
              effectively the same thing as GRUB's encrypted /boot over
              the network with iPXE's code signing and HTTPS support,
              if you control the DHCP server.
```
