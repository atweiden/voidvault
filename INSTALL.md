Install
=======

If you intend to run Voidvault on the current stock LiveCD, *you must
increase the size of the root partition* to avoid running out of disk
space. Using the official Void Linux ISO, when you see the boot loader
screen, press <kbd>Tab</kbd> and [append the following][overlayfs] to the
kernel line: `rd.live.overlay.overlayfs=1`. Then, press <kbd>Enter</kbd>.

In order to use Voidvault, install [Rakudo Perl 6][rakudo]. Voidvault
will automatically resolve all other dependencies.

Alternatively, you can use my custom [Void ISO][voidiso]. This ISO ships
with Rakudo Perl 6 pre-installed, and has ample space in its rootfs.


Installing Rakudo Perl 6
------------------------

```sh
xbps-install -Syv rakudo
```


Running Voidvault
-----------------

Fetch Voidvault sources with Curl:

```sh
# official release tarball
VERSION=1.10.0
curl \
  -L \
  -O \
  https://github.com/atweiden/voidvault/releases/download/$VERSION/voidvault-$VERSION.tar.gz
tar xvzf voidvault-$VERSION.tar.gz
cd voidvault-$VERSION

# latest snapshot
curl \
  -L \
  -o '#1-#2.#3' \
  https://github.com/atweiden/{voidvault}/archive/{master}.{tar.gz}
tar xvzf voidvault-master.tar.gz
cd voidvault-master
```

Fetch Voidvault sources with Git:

```sh
git clone https://github.com/atweiden/voidvault
cd voidvault
```

Run Voidvault (as root):

```sh
export PATH="$(realpath bin):$PATH"
export PERL6LIB="$(realpath lib)"
# for rakudo-2019.11
export PERL6_HOME=/usr/lib/perl6
voidvault --help
```


[overlayfs]: https://github.com/atweiden/voidvault/pull/3
[rakudo]: https://github.com/rakudo/rakudo
[voidiso]: https://github.com/atweiden/voidiso/releases
