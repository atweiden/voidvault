Install
=======

If you intend to run Voidvault on the current stock LiveCD, *you must
free up disk space by removing pkgs* to avoid running out of room on
the LiveCD's rootfs. As of 2018-08-11, Voidvault accomplishes this by
automatically removing `linux-firmware-network`. This frees up over
100MB of disk space.

In order to use Voidvault, install [Rakudo Perl 6][rakudo]. Voidvault
will automatically resolve all other dependencies.


Installing Rakudo Perl 6
------------------------

```sh
xbps-install -Syv rakudo
```


Running Voidvault
-----------------

Fetch Voidvault sources with Curl:

```sh
curl \
  -L \
  -o '#1-#2.#3' \
  https://github.com/atweiden/{voidvault}/archive/{master}.{tar.gz}
cd voidvault-master
```

Fetch Voidvault sources with Git:

```sh
git clone https://github.com/atweiden/voidvault
cd voidvault
```

Run Voidvault:

```sh
export PERL6LIB=lib
bin/voidvault --help
```


[rakudo]: https://github.com/rakudo/rakudo
