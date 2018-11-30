Install
=======

If you intend to run Voidvault on the current stock LiveCD, *you must
free up disk space by removing pkgs* to avoid running out of room on the
LiveCD's rootfs. Removing `linux-firmware-network` frees up over 100MB
of disk space.

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
VERSION=1.4.2
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

Run Voidvault:

```sh
export PATH="$(realpath bin):$PATH"
export PERL6LIB="$(realpath lib)"
voidvault --help
```


[rakudo]: https://github.com/rakudo/rakudo
[voidiso]: https://github.com/atweiden/voidiso/releases
