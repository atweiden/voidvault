use v6;
use Voidvault::Constants;
use Voidvault::Parser::FstabEntry;
use Voidvault::Types;
unit role Voidvault::Replace::Fstab;

my constant $FILE = $Voidvault::Constants::FILE-FSTAB;

multi method replace(Str:D $ where $FILE, Str:D $path where .so --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @replace =
        $file.IO.lines
        ==> replace('secure-mount', :$path);
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

# EFI System Partition (ESP) must be mounted after C</boot>
multi sub replace(
    'secure-mount',
    Str:D @line,
    Str:D :$path! where $Voidvault::Constants::DIRECTORY-EFI
    --> Array[Str:D]
)
{
    # ESP fstab entry
    my Int:D $index = gen-fstab-entry-path-index(@line, :$path);
    my Str:D $line = @line[$index];

    # commented out label above ESP fstab entry, by C<genfstab>
    my Int:D $index-label = $index - 1;
    my Str:D $line-label = @line[$index-label];

    # remove commented out ESP label, ESP fstab entry, blank line
    # append blank line, commented out ESP label, ESP fstab entry
    @line
    ==> replace('secure-mount', $line-label, $line, :index($index-label));
}

multi sub replace(
    'secure-mount',
    Str:D @line,
    Str:D :$path! where .so
    --> Array[Str:D]
)
{
    # fstab entry of interest
    my Int:D $index = gen-fstab-entry-path-index(@line, :$path);
    my Str:D $line = @line[$index];

    # commented out label above fstab entry of interest, by C<genfstab>
    my Int:D $index-label = $index - 1;

    # bind mount instructions
    my Str:D $bind = "$path $path none bind 0 0";

    # remount instructions
    my Str:D $remount = Voidvault::Parser::FstabEntry.gen-secure-remount($line);

    # remove commented out label, fstab entry of interest, blank line
    # append blank line, bind mount instructions, remount instructions
    @line
    ==> replace('secure-mount', $bind, $remount, :index($index-label));
}

multi sub replace(
    'secure-mount',
    # either bind mount instructions or original commented out label
    Str:D $first,
    # either remount instructions or original fstab entry
    Str:D $second,
    # original fstab lines
    Str:D @line,
    # index at which to begin culling obsolete fstab entries
    Int:D :$index!
    --> Array[Str:D]
)
{
    # cull 2 obsolete fstab entries beginning at C<$index> plus blank line
    @line.splice($index, 3);
    push(@line, '', $first, $second);
    @line;
}

# identify fstab entry of interest
sub gen-fstab-entry-path-index(Str:D @line, Str:D :$path! where .so --> Int:D)
{
    my Regex:D $regex-fstab-entry = gen-regex-fstab-entry($path);
    my Int:D $index = @line.first($regex-fstab-entry, :k)
        or die("Sorry, unexpectedly missing target path ($path) in /etc/fstab");
}

# identify fstab entry of interest
sub gen-regex-fstab-entry(Str:D $path where .so --> Regex:D)
{
    my Regex:D $regex-fstab-entry = /^ 'UUID=' \S+ \s+ $path \s.* $/;
}

multi method replace(Str:D $ where $FILE --> Nil)
{
    my AbsolutePath:D $chroot-dir = $.config.chroot-dir;
    my Str:D $file = sprintf(Q{%s%s}, $chroot-dir, $FILE);
    my Str:D @replace =
        $file.IO.lines
        # add /proc mount with hidepid
        ==> replace('procfs', 'add')
        # rm default /tmp mount in fstab
        ==> replace('tmpfs', 'rm')
        # add /tmp mount with options
        ==> replace('tmpfs', 'add');
    my Str:D $replace = @replace.join("\n");
    spurt($file, $replace ~ "\n");
}

multi sub replace(
    'procfs',
    'add',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.elems;
    my Str:D $replace =
        'proc /proc proc nodev,noexec,nosuid,hidepid=2,gid=proc 0 0';
    @line[$index] = $replace;
    @line;
}

multi sub replace(
    'tmpfs',
    'rm',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.first(/^tmpfs/, :k);
    @line.splice($index, 1);
    @line;
}

multi sub replace(
    'tmpfs',
    'add',
    Str:D @line
    --> Array[Str:D]
)
{
    my UInt:D $index = @line.elems;
    my Str:D $replace =
        'tmpfs /tmp tmpfs mode=1777,strictatime,nodev,noexec,nosuid 0 0';
    @line[$index] = $replace;
    @line;
}

# vim: set filetype=raku foldmethod=marker foldlevel=0:
