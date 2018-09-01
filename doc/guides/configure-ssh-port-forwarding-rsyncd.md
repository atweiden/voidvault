# Configure SSH Port Forwarding for `rsyncd`

**On guest machine**:

```sh
cat >> /etc/rsyncd.conf <<'EOF'
uid = nobody
gid = nogroup
use chroot = yes
munge symlinks = yes
exclude = /rsyncd-munged/
max connections = 7
address = 127.0.0.1
port = 1006
# limit clients to localhost
hosts allow = 127.0.0.1
# disallow file deletion
refuse options = c delete

[rsyncd]
path = /srv/rsyncd/jail
comment = rsync file uploads/downloads area
# allow clients to upload files
read only = false
EOF

# make rsyncd dir with permissions
mkdir -p /srv/rsyncd/jail
chown -R nobody:nogroup /srv/rsyncd/jail

# bring up rsyncd
touch /etc/sv/rsyncd/down
ln -s /etc/sv/rsyncd /var/service
sv up rsyncd

# bring up sshd
touch /etc/sv/sshd/down
ln -s /etc/sv/sshd /var/service
sv up sshd
```

**On host machine**:

```sh
# map host's 127.0.0.1:10006 to guest's 127.0.0.1:1006
ssh -N -T -L 10006:127.0.0.1:1006 variable@vbox-void64
```

```sh
# rsyncd user account "pub" is arbitrarily named
rsync --address 127.0.0.1 --port=10006 rsync://pub@127.0.0.1/

# ls
rsync --address 127.0.0.1 --port=10006 rsync://pub@127.0.0.1/rsyncd

# upload file
rsync --address 127.0.0.1 --port=10006 hello.txt rsync://pub@127.0.0.1/rsyncd

# download file
rsync --address 127.0.0.1 --port=10006 rsync://pub@127.0.0.1/rsyncd/hello.txt .

_rsync_opts=()
# copy directories recursively
_rsync_opts+=('--recursive')
# preserve permissions
_rsync_opts+=('--perms')
# output numbers in a more human-readable format
_rsync_opts+=('--human-readable')
# print information showing the progress of the transfer
_rsync_opts+=('--progress')
# verbosely
_rsync_opts+=('--verbose')

# upload directory
rsync \
  "${_rsync_opts[@]}" \
  --address 127.0.0.1 \
  --port 10006 \
  /path/to/dir \
  rsync://pub@127.0.0.1/rsyncd

# download directory
rsync \
  "${_rsync_opts[@]}" \
  --address 127.0.0.1 \
  --port 10006 \
  rsync://pub@127.0.0.1/rsyncd/dir \
  .
```
