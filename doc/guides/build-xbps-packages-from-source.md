# Build XBPS Packages From Source

Bootstrap `xbps-src`:

```sh
git clone https://github.com/void-linux/void-packages
cd void-packages
git checkout -b exp
./xbps-src binary-bootstrap
```

Develop:

```sh
mkdir srcpkgs/new-pkg
vim srcpkgs/new-pkg/template
```

Build:

```sh
./xbps-src pkg new-pkg
```

Install:

```sh
# xbps-install -Syv -i -R /path/to/hostdir/binpkgs/exp new-pkg
xbps-install xtools
xi new-pkg
```
