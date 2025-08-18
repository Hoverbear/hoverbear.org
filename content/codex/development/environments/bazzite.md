+++
title = "Bazzite"
description = "If SteamOS and Silverblue had a kid..."
weight = 0
template =  "blog/single.html"
insert_anchor_links = "heading"

[extra]
in_menu = true

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Roseanna Smith"
source = "https://unsplash.com/photos/-qzLjuJEmsE"
+++

I can't believe it's not SteamOS!

<!-- more -->

## 1password with Bazzite

This one is kinda fussy, ublue distros have lots of weird business happening. TL;DR is you almost certainly want native 1password & flatpak'd Firefox since you're gonna want SSH integration and gpg signing.

Set up native 1password using [the `rpm-ostree` method](https://monospacementor.com/wiki/Notes/Install+1Password+on+Fedora+Silverblue)

Then [set up native 1password to work with Flatpak's Firefox](https://gist.github.com/Hoverbear/fd164e63ec6a19bb74ecabc4c1a88dd4).

## "Developer mode"

There is a [`bazzite-dx`](github.com/ublue-os/bazzite-dx) variant that includes a native VSCode. (This is possibly desirable, at time of writing the FlatPak was broken...)

On the KDE variant you can probably just run:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ublue-os/bazzite-dx:stable
```

## Docker & Containers

The "Developer Mode" has `podman`, use that. Otherwise `lima` is around via `brew`.

## Copr

Many guides will discuss a `dnf copr` command, you can just directly use `copr`.

Eg.

```bash
sudo dnf copr enable $ORG/$REPO
sudo dnf install $PACKAGE
```

Becomes:

```bash
sudo copr enable $ORG/$REPO
sudo rpm-ostree install $PACKAGE
```

## Broken Spotify

Sometimes Spotify can seemingly just randomly break. [It can help to delete it's config and try again](https://www.reddit.com/r/Fedora/comments/1bls16k/comment/l1974s9/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button):

```bash
rm -rf ~/.var/app/com.spotify.Client
flatpak run com.spotify.Client
```