+++
title = "Arch Linux on Docker Revisited"
aliases = ["2016/01/13/docker-archlinux/"]
template = "blog/single.html"
[taxonomies]
tags = [
 "Containers",
 "Arch Linux",
]
[extra]
[extra.image]
path =  "cover.jpg"
+++

Back in [2014](/2014/07/14/arch-docker-baseimage/) when I was learning about [Docker](https://docker.com) I got around to making a base image for [Arch Linux](http://archlinux.org/). It was a really fun exploration and I got to know a lot more about how Docker worked from it. I'd highly suggest trying to make your own sometime!

Docker has matured a lot since, and I've enjoyed following it. I took some time this last week to revisit my Arch Linux image and ensure it's still functional. I wasn't surprised when the scripts continued to work just fine, even after two years.

With nothing broken, I knew I only had one choice. **I had to improve it!**

<!-- more -->

> Want to get started? See it on the hub [here](https://hub.docker.com/r/hoverbear/archlinux/), Github [here](https://github.com/Hoverbear/docker-archlinux), or pull it down with `docker run --tty --interactive --rm hoverbear/archlinux /bin/bash` and play around.

## Improvements ##

I spent most of my time working on having the [Travis-CI](http://travis-ci.org/) service be able to build and deploy new versions in an automated fashion. This was primarily, for me, a trust thing. I don't feel comfortable running containers I haven't seen the build process for, and you shouldn't either.

While the Docker Hub has "Automated" builds there doesn't seem to be much of a solution for having trusted base images, only images built via a `Dockerfile`. Perhaps there is a way to scheme and subvert this via the `scratch` image but I did not find this avenue enjoyable.

Thankfully, Travis did this job stellarly after a few hiccups. The biggest problem was that Travis runs a version of Ubuntu LTS and the *normal* Arch install process assumes it's happening on a relatively recent Linux, if not Arch itself.

I got around this problem in a slightly dirty way and pinned recent versions of the necessary packages, then upgraded the host into a (slightly terrifying) abomination. I'd like to find a cleaner way of doing this, possibly from inside of a `docker` container like in the `Makefile`.

## Playing Around ##

What's a good blog post without some fun examples?

**Spawning 10 Arch containers in parallel and having them all pipe to the same file:**

```bash
for i in {1..10}; do (docker run --rm -v $(pwd):/here hoverbear/archlinux /bin/bash -c "echo $i >> here/checkin" &); done
```

A few seconds later:

```bash
$ cat checkin
6
3
4
5
1
8
10
2
7
9
```

**Making an image to build your favorite Rust project:**

```dockerfile
FROM hoverbear/archlinux
MAINTAINER Ana Hobden <ana@hoverbear.org>

# It's always a good idea to update Arch, then install deps.
RUN pacman -Syu
RUN pacman -S git file awk gcc --noconfirm

# Install Multirust
RUN git clone --recursive https://github.com/brson/multirust
WORKDIR multirust
RUN git submodule update --init
RUN ./build.sh
RUN ./install.sh

RUN multirust default "nightly"

# /source - Should mount the user code.
VOLUME [ "/source" ]

# Change the Workdir to /source
WORKDIR /source
```

Running it inside your favorite project folder:

```bash
docker run -t -i --rm=true -v $(pwd):/source rust cargo build
```

You can even get this image [here](https://hub.docker.com/r/hoverbear/rust/) if you'd like!

## Conclusion ##

I hope you have a great time using this image and please let me know if there is any way I can make it better!
