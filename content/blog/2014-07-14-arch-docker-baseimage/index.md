+++
title = "Arch Docker Baseimage"
aliases = ["2014/07/14/arch-docker-baseimage/"]
template = "blog/single.html"
[taxonomies]
tags = [
  "Containers",
  "Arch Linux",
  "Tutorials",
]
+++

## Problem ##

You need a base image of Arch Linux that you're sure is a-okay.

<!-- more -->

### Compounding Factors ###

* Base images currently can't be so-called 'Trusted Builds' built by the repository itself. You have *no way* of verifying the integrity of the images available.
* Arch is very much a moving target distribution. Any images you do pull are likely to be out of date.
* You don't have an existing Arch Linux install, which the [current scripts](https://github.com/dotcloud/docker/blob/master/contrib/mkimage-arch.sh) require. and don't want to make one, or use someone else's container or install to build your image, again, going back to trust.
* The Arch Netinstall ISO doesn't have enough disposable storage to run the [current scripts](https://github.com/dotcloud/docker/blob/master/contrib/mkimage-arch.sh).

## Solution ##

### Dependencies ###
You'll need:

* `gpg`
* `curl`
* `docker`

### Get an Arch Chroot ###
On any 64-bit Linux 2.6.23 or later you can create your base image via a chroot.

```bash
# Make some space
mkdir archbuild
cd archbuild
# Get the Image
VERSION=$(curl https://mirrors.kernel.org/archlinux/iso/latest/ | grep -Poh '(?<=archlinux-bootstrap-)\d*\.\d*\.\d*(?=\-x86_64)' | head -n 1)
curl https://mirrors.kernel.org/archlinux/iso/latest/archlinux-bootstrap-$VERSION-x86_64.tar.gz > archlinux-bootstrap-$VERSION-x86_64.tar.gz
curl https://mirrors.kernel.org/archlinux/iso/latest/archlinux-bootstrap-$VERSION-x86_64.tar.gz.sig > archlinux-bootstrap-$VERSION-x86_64.tar.gz.sig
# Pull Pierre Schmitz PGP Key.
# http://pgp.mit.edu:11371/pks/lookup?op=vindex&fingerprint=on&exact=on&search=0x4AA4767BBC9C4B1D18AE28B77F2D434B9741E8AC
gpg --keyserver pgp.mit.edu --recv-keys 9741E8AC
# Verify its integrity.
gpg --verify archlinux-bootstrap-$VERSION-x86_64.tar.gz.sig
```
Check the output, make sure the signature is good. You'll likely see a trust warning, that's fine, you didn't mark the key trusted.

### Getting In ###

```bash
# Extract
tar xvf archlinux-bootstrap-$VERSION-x86_64.tar.gz
# Hop in
sudo ./root.x86_64/bin/arch-chroot root.x86_64
```
You should notice you shell looks like `sh-4.3#`. Furthermore, `pacman` should be available.

### Setup ###
**In the chroot**:

```bash
# Setup a mirror.
echo 'Server = https://mirrors.kernel.org/archlinux/\$repo/os/\$arch' > /etc/pacman.d/mirrorlist
# Setup Keys
pacman-key --init
pacman-key --populate archlinux
# Base without the following packages, to save space.
# linux jfsutils lvm2 cryptsetup groff man-db man-pages mdadm pciutils pcmciautils reiserfsprogs s-nail xfsprogs vi
pacman -Syu --noconfirm bash bzip2 coreutils device-mapper dhcpcd gcc-libs gettext glibc grep gzip inetutils iproute2 iputils less libutil-linux licenses logrotate psmisc sed shadow sysfsutils systemd-sysvcompat tar texinfo usbutils util-linux which
# Pacman doesn't let us force ignore files, so clean up.
pacman -Sc --noconfirm
# Install stuff
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
exit
```
**Outside of the chroot** (You may need to be root):

```bash
# udev doesnt work in containers, rebuild /dev
# Taken from https://raw.githubusercontent.com/dotcloud/docker/master/contrib/mkimage-arch.sh
DEV=root.x86_64/dev
rm -rf $DEV
mkdir -p $DEV
mknod -m 666 $DEV/null c 1 3
mknod -m 666 $DEV/zero c 1 5
mknod -m 666 $DEV/random c 1 8
mknod -m 666 $DEV/urandom c 1 9
mkdir -m 755 $DEV/pts
mkdir -m 1777 $DEV/shm
mknod -m 666 $DEV/tty c 5 0
mknod -m 600 $DEV/console c 5 1
mknod -m 666 $DEV/tty0 c 4 0
mknod -m 666 $DEV/full c 1 7
mknod -m 600 $DEV/initctl p
mknod -m 666 $DEV/ptmx c 5 2
ln -sf /proc/self/fd $DEV/fd
```

### Import the Image ###
**Outside of the chroot** (You may need to be root):

```bash
USER='hoverbear'
tar --numeric-owner -C root.x86_64 -c .  | docker import - $USER/archlinux
```

### Test It ###
```bash
docker run --rm=true -t -i $USER/archlinux /bin/bash
```
Give it a try!


## A full, start to end script ##
You can grab a fully automated script [here](https://github.com/Hoverbear/docker-archlinux).
