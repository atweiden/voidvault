Install
=======

In order to use Voidvault, install [Raku][rakudo]. Voidvault will
automatically resolve all other dependencies.


Installing Raku
---------------

```sh
xbps-install -Syv rakudo
```


Running Voidvault
-----------------

Fetch Voidvault sources with Curl:

```sh
# official release tarball
VERSION=1.11.1
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
export RAKULIB="$(realpath lib)"
export RAKUDO_HOME=/usr/lib/raku
voidvault --help
```


[overlayfs]: https://github.com/atweiden/voidvault/pull/3
[rakudo]: https://github.com/rakudo/rakudo
[voidiso]: https://github.com/atweiden/voidiso/releases
