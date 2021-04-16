+++
title = "Custom live media with Nix flakes"
description = "How to make live media with Nix flakes."
sort_by = "date"
template =  "blog/single.html"

[taxonomies]
tags = [
    "Nix",
]

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Darius Cotoi"
source = "https://unsplash.com/photos/d8cKjamtQH4"
+++

I've always been quite fond of booting live media. To test or install a new operating system, to recover an old one, find some privacy, or to do a myriad of other specialized tasks. LiveUSBs and liveCDs introduced to me a new way of thinking about my computer.

It improved my mental model of the separation of between the machine, the UEFI (or BIOS), any bootloaders, and the operating system itself.

As I learnt about them over 15 years ago I spent months exploring ways to use them. I used them to rescue systems for myself and others, diagnose hardware, recovery files, and quickly set up machines. 

With Nix flakes, we can define a custom live system and build it with minimal steps. This NixOS live system which could be a composition of existing NixOS modules, or an entirely new configuration.

<!-- more -->

> Nix flakes are experimental. The tools and APIs discussed here may have changed since this was posted.
>
> **Learn how to enable Nix flakes [here](https://nixos.wiki/wiki/Flakes#Installing_flakes).**

# An example

Here's a small example flake that shows a configuration definition which can be built into a stateless LiveCD or LiveUSB, as well as used for a 'normal' install:

```nix
# flake.nix
{
  description = "Example";
  inputs.nixos.url = "github:nixos/nixpkgs/nixos-unstable";
  outputs = { self, nixos }: {

    # Package for `nix build` output.
    packages."x86_64-linux".exampleIso =
        self.nixosConfigurations.exampleIso.config.system.build.isoImage;

    nixosConfigurations = let
      # Shared base configuration.
      exampleBase = {
        system = "x86_64-linux";
        modules = [
          # Common system modules...
        ];
      };
    in {
      exampleIso = nixos.lib.nixosSystem {
        inherit (exampleBase) system;
        modules = exampleBase.modules ++ [
          "${nixos}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        ];
      };
      example = nixos.lib.nixosSystem {
        inherit (exampleBase) system;
        modules = exampleBase.modules ++ [
          # Modules for installed systems only.
        ];
      };
    };
  };
}
```

# Building & Use

Using `nix build` (or other commands) will create a `flake.lock` file which pins the versions of the `inputs`. Nix flakes require a Git repo, so first intialize that:

```bash
git init
git add flake.nix
```

Then an `exampleIso` could be produced with the following invocation:

```bash
nix build .#exampleIso
```

Nix will output an ISO (and some other things) to `./result/`. Then, the operator could install it to media:

```bash
USB_PATH=/dev/null # Change me
cp -vi result/iso/*.iso $USB_PATH
```

From the booted live media, they could format and mount their disks, then install the 'real' system via:

```bash
nixos-install --flake .#example
```

If desired, the flake could be located at a URI, such as `github:hoverbear-consulting/flake#example`, allowing the operator not to need to worry about fetching or persisting the configuration.

Later, the operator could modify the configuration, and have the machine adopt the new state:

```bash
nixos-rebuild switch --flake .#example
```

If using a remote URI for the flake, an invocation of `nix flake update` may be required, as flakes (rightly) use lock files.

# Going farther

The [`NixOS/nigpkgs` installer modules](https://github.com/NixOS/nixpkgs/tree/master/nixos/modules/installer/cd-dvd/) provide a number of useful bases for images. For example, for a graphical base LiveUSB the `${nixos}/modules/installer/cd-dvd/installation-cd-graphical-plasma5.nix` module could be used instead.

As your configuration grows, you may find it necessary to have certain modules only loaded when not running as live media, or you may choose to implement your own live media builder.

While I've not had much luck with cross compiling live media for different architectures (eg. building an aarch64 media through an x86_64 toolchain), I have had some luck using `binfmt`. Setting that up looks like this:

```nix
# /etc/nixos/configuration.nix
{
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
}
```

Then boldly build the ISO through direct address (after you change the architectures in the example above):

```bash
nix build --flake .#packages.aarch64-linux.exampleIso
```

You can also use this idea to create recovery media with custom hardware support, like [the SolidRun LX2K](https://github.com/Hoverbear/lx2k-nix).
