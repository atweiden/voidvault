use v6;
use Voidvault::Constants;
use Voidvault::DeviceInfo;
use Voidvault::Types;
use Voidvault::Utils;
unit role Voidvault::Replace::Grub::Utils;

my constant $FILE = $Voidvault::Constants::FILE-GRUB-DEFAULT;

method set-log-level(Str:D $log-level, Str:D @grub-cmdline-linux --> Nil)
{
    my Str:D $gen-log-level = gen-log-level($log-level);
    my Str:D $set-log-level = sprintf(Q{loglevel=%s}, $gen-log-level);
    push(@grub-cmdline-linux, $set-log-level);
}

# kernel message limit level accessed phonetically
multi sub gen-log-level('emergency' --> Str:D)     { '0' }
multi sub gen-log-level('alert' --> Str:D)         { '1' }
multi sub gen-log-level('critical' --> Str:D)      { '2' }
multi sub gen-log-level('error' --> Str:D)         { '3' }
multi sub gen-log-level('warning' --> Str:D)       { '4' }
multi sub gen-log-level('notice' --> Str:D)        { '5' }
multi sub gen-log-level('informational' --> Str:D) { '6' }
multi sub gen-log-level('debug' --> Str:D)         { '7' }

method enable-luks(
    Str:D @grub-cmdline-linux,
    Str:D :$partition-vault! where .so,
    Str:D :$vault-name! where .so
    --> Nil
)
{
    push(@grub-cmdline-linux, 'rd.luks=1');
    my DeviceInfo:D $device-info =
        Voidvault::Utils.device-info($partition-vault);
    enable-luks(@grub-cmdline-linux, :$device-info, :$vault-name);
}

multi sub enable-luks(
    Str:D @grub-cmdline-linux,
    DeviceInfo[DeviceLocator::UUID] :$device-info! where .so,
    Str:D :$vault-name! where .so
    --> Nil
)
{
    my Str:D $vault-uuid = $device-info.uuid;
    push(@grub-cmdline-linux, "rd.luks.uuid=$vault-uuid");
    push(@grub-cmdline-linux, "rd.luks.name=$vault-uuid=$vault-name");
}

multi sub enable-luks(
    Str:D @grub-cmdline-linux,
    DeviceInfo[DeviceLocator::PARTUUID] :$device-info! where .so,
    Str:D :$vault-name! where .so
    --> Nil
)
{
    my Str:D $vault-partuuid = $device-info.partuuid;
    push(@grub-cmdline-linux, "rd.luks.partuuid=$vault-partuuid");
    push(@grub-cmdline-linux, "rd.luks.name=$vault-partuuid=$vault-name");
}

multi sub enable-luks(
    Str:D @grub-cmdline-linux,
    DeviceInfo[DeviceLocator::ID] :$device-info! where .so,
    Str:D :$vault-name! where .so
    --> Nil
)
{
    my Str:D $vault-id = $device-info.id-serial-short;
    push(@grub-cmdline-linux, "rd.luks.serial=$vault-id");
    push(@grub-cmdline-linux, "rd.luks.name=$vault-id=$vault-name");
}

method enable-serial-console(
    Str:D @grub-cmdline-linux,
    Str:D $subject where .so
    --> Nil
)
{
    # e.g. console=tty0
    my Str:D $virtual = gen-console('virtual');
    # e.g. console=ttyS0,115200n8
    my Str:D $serial = gen-console('serial', $subject);
    # enable both serial and virtual console on boot
    push(@grub-cmdline-linux, $virtual);
    push(@grub-cmdline-linux, $serial);
}

multi sub gen-console('virtual' --> Str:D)
{
    # e.g. console=tty0
    my Str:D $virtual =
        sprintf('console=%s', $Voidvault::Constants::CONSOLE-VIRTUAL);
}

multi sub gen-console('serial', Str:D $subject where .so --> Str:D)
{
    # e.g. console=ttyS0,115200n8
    my Str:D $serial = sprintf(
        'console=%s,%s%s%s',
        $Voidvault::Constants::CONSOLE-SERIAL,
        $Voidvault::Constants::GRUB-SERIAL-PORT-BAUD-RATE,
        %Voidvault::Constants::GRUB-SERIAL-PORT-PARITY{$Voidvault::Constants::GRUB-SERIAL-PORT-PARITY}{$subject},
        $Voidvault::Constants::GRUB-SERIAL-PORT-WORD-LENGTH-BITS
    );
}

method enable-security-features(Str:D @grub-cmdline-linux --> Nil)
{
    # disable slab merging (makes many heap overflow attacks more difficult)
    push(@grub-cmdline-linux, 'slab_nomerge=1');
    # always enable Kernel Page Table Isolation (to be safe from Meltdown)
    push(@grub-cmdline-linux, 'pti=on');
    # unprivilege RDRAND (distrusts CPU for initial entropy at boot)
    push(@grub-cmdline-linux, 'random.trust_cpu=off');
    # zero memory at allocation and free time
    push(@grub-cmdline-linux, 'init_on_alloc=1');
    push(@grub-cmdline-linux, 'init_on_free=1');
    # enable page allocator freelist randomization
    push(@grub-cmdline-linux, 'page_alloc.shuffle=1');
    # randomize kernel stack offset on syscall entry
    push(@grub-cmdline-linux, 'randomize_kstack_offset=on');
    # disable vsyscalls (inhibits return oriented programming)
    push(@grub-cmdline-linux, 'vsyscall=none');
    # restrict access to debugfs
    push(@grub-cmdline-linux, 'debugfs=off');
    # enable all mitigations for spectre variant 2
    push(@grub-cmdline-linux, 'spectre_v2=on');
    # disable speculative store bypass
    push(@grub-cmdline-linux, 'spec_store_bypass_disable=on');
    # disable TSX, enable all mitigations for TSX Async Abort
    # vulnerability, and disable SMT
    push(@grub-cmdline-linux, 'tsx=off');
    push(@grub-cmdline-linux, 'tsx_async_abort=full,nosmt');
    # enable all mitigations for MDS vulnerability and disable SMT
    push(@grub-cmdline-linux, 'mds=full,nosmt');
    # enable all mitigations for L1TF vulnerability, and disable SMT
    # and L1D flush runtime control
    push(@grub-cmdline-linux, 'l1tf=full,force');
    # force disable SMT
    push(@grub-cmdline-linux, 'nosmt=force');
    # mark all huge pages in EPT non-executable (mitigates iTLB multihit)
    push(@grub-cmdline-linux, 'kvm.nx_huge_pages=force');
    # always perform cache flush when entering guest vm (limits unintended
    # memory exposure to malicious guests)
    push(@grub-cmdline-linux, 'kvm-intel.vmentry_l1d_flush=always');
    # enable IOMMU (prevents DMA attacks)
    push(@grub-cmdline-linux, 'intel_iommu=on');
    push(@grub-cmdline-linux, 'amd_iommu=on');
    push(@grub-cmdline-linux, 'amd_iommu=force_isolation');
    push(@grub-cmdline-linux, 'iommu=force');
    # force IOMMU TLB invalidation (avoids access to stale data contents)
    push(@grub-cmdline-linux, 'iommu.passthrough=0');
    push(@grub-cmdline-linux, 'iommu.strict=1');
    # disable busmaster bit on all PCI bridges (avoids holes in IOMMU)
    push(@grub-cmdline-linux, 'efi=disable_early_pci_dma');
    # always panic on uncorrected errors, log corrected errors
    push(@grub-cmdline-linux, 'mce=0');
    push(@grub-cmdline-linux, 'printk.time=1');
}

method enable-radeon(Str:D @grub-cmdline-linux --> Nil)
{
    push(@grub-cmdline-linux, 'radeon.dpm=1');
}

method disable-ipv6(Str:D @grub-cmdline-linux --> Nil)
{
    push(@grub-cmdline-linux, 'ipv6.disable=1');
}

method finalize(
    Str:D $subject where 'GRUB_CMDLINE_LINUX_DEFAULT',
    Str:D @grub-cmdline-linux,
    AbsolutePath:D :$chroot-dir! where .so
    --> Nil
)
{
    my Str:D $grub-cmdline-linux = @grub-cmdline-linux.join(' ');
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @line = $file.IO.lines;
    my UInt:D $index = @line.first(/^$subject'='/, :k);
    my Str:D $replace = sprintf(Q{%s="%s"}, $subject, $grub-cmdline-linux);
    @line[$index] = $replace;
    my Str:D $finalize = @line.join("\n");
    spurt($file, $finalize ~ "\n");
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
