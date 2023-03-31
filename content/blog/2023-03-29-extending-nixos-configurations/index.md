+++
title = "Extending NixOS Configurations"
description = "Using Nix flakes to extend an existing NixOS configuration with additional settings or modules."
template =  "blog/single.html"

[taxonomies]
tags = [
    "Nix",
]

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Kiwihug"
source = "https://unsplash.com/photos/Kmk4ga-_V5I"
+++

[NixOS][nixos] [modules][nixos-modules] and configurations offer us a tantilizing way to express and share systems. My friends and I can publish our own flakes containing `nixosModules` and/or `nixosConfigurations` outputs which can be imported, reused, and remixed. When it comes to secret projects though, that openness and ease of sharing can be a bit of a problem.

Let's pretend my friend wants to share a secret NixOS module or package with me, they've already given me access to the GitHub repository, and now I need to add it to my flake. My [flake][hoverbear-consulting-flake] is public and has downstream users. I can't just up and add it as an input. For one thing, it'd break everything downstream. More importantly, my friend asked me not to.

It's terribly inconvienent to add the project as an input and be careful to never commit that change to the repository. Worse, if I did screw up and commit it, my friend might be disappointed in me. We simply can't have that.

Let's explore how to create a flake which extends some existing flake, a pattern which can be combined with a `git+ssh` flake URL to resolve this precarious situation.

<!-- more -->

This same situation strategy can be applied to other outputs of a flake, and can be combined with [Configurable Nix Packages][configurable-nix-packages].

## Extending a Flake

Let's assume for a moment we have a simple flake called `original` with a `nixosConfiguration` and a `nixosModule`:

```nix
# original/flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.default = { config, pkgs, lib, ... }: {
      # Create a file `/etc/original-marker`
      environment.etc.original-marker.text = "Hello!";

      # You can ignore these, just keeping things small
      boot.initrd.includeDefaultModules = false;
      documentation.man.enable = false;
      boot.loader.grub.enable = false;
      fileSystems."/".device = "/dev/null";
      system.stateVersion = "22.05";
    };

    nixosConfigurations.teapot = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        self.nixosModules.default
      ];
    };
  };
}

```

While our little demo configuration, `teapot`, might not be a very practical system for hardware (or even a VM) it's a perfectly valid NixOS expression which we can build and inspect the resultant output filesystem of:

```bash
extension-demo/original 
❯ nix build .#nixosConfigurations.teapot.config.system.build.toplevel                                 

extension-demo/original 
❯ cat result/etc/original-marker 
Hello!⏎ 
```

Now, let's assume there exists some other flake, called `extension` that looks like this:

```nix
# extension/flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
  };

  outputs = { self, nixpkgs }: {
    nixosModules.default = { config, pkgs, lib, ... }: {
      # Create a file `/etc/extension-marker`
      environment.etc.extension-marker.text = "Hi!";
    };
  };
}
```

Our goal is to create a `teapot` with the `extension.nixosModules.default` module included.

To do that, we'll create a new flake, called `extended` which looks like this:

```nix
# extended/flake.nix
{
  inputs = {
    original.url = "/home/ana/git/extension-demo/original";
    nixpkgs.follows = "original/nixpkgs";
    extension = {
      url = "/home/ana/git/extension-demo/extension";
      inputs.nixpkgs.follows = "original/nixpkgs";
    };
  };

  outputs = { self, nixpkgs, original, extension }:
    original.outputs // {
    nixosConfigurations.teapot =
      original.nixosConfigurations.teapot.extendModules {
        modules = [
          extension.nixosModules.default
        ];
      };
  };
}
```

Because of `outputs = { self, nixpkgs, original, extension }: original.outputs // { /* ... */ }` this `extended` flake has the same outputs of `original`, plus whatever overrides we add inside `{ /* ... */ }`.

```bash
extension-demo/extended 
❯ nix flake show
path:/home/ana/git/extension-demo/extended?lastModified=1680125924&narHash=sha256-EV4jQJ5H3mypuOt4H174lII2yhnaUbZ9rbML2mjyRlI=
├───nixosConfigurations
│   └───teapot: NixOS configuration
└───nixosModules
    └───default: NixOS module

```

We call [`extendModules`][github-nix-extendModules] on the original `nixosConfiguration.teapot` to extend the configuration with new modules, in this case, our `extension.nixosModules.default`.

Now we can inspect the resultant output filesystem:

```bash
extension-demo/extended 
❯ nix build .#nixosConfigurations.teapot.config.system.build.toplevel

extension-demo/extended took 2s 
❯ cat result/etc/original-marker 
Hello!⏎                                                                                                                                                              

extension-demo/extended 
❯ cat result/etc/extension-marker 
Hi!⏎  
```



## Using private GitHub inputs in flakes

While the `github:username/repository` flake paths utilize Github's API and work well for public repositories, you may experience issues trying to use it with a private repository.

In these cases, try using the `git+ssh` protocol. For example:

```nix
{
  inputs = {
    original.url = "/home/ana/git/extension-demo/original";
    nixpkgs.follows = "original/nixpkgs";
    extension = {
      url = "git+ssh://git@github.com/hoverbear/top-secret-project.git";
      inputs.nixpkgs.follows = "original/nixpkgs";
    };
  };

  outputs = { self, nixpkgs, original, extension }: 
    original.outputs // {
    nixosConfigurations.teapot = 
      original.nixosConfigurations.teapot.extendModules {
        modules = [
          extension.nixosModules.default
        ];
      };
  };
}
```

Running `nix flake update` should then use your SSH key and work, as long as you have the ability to clone that repository over SSH.


[hoverbear-consulting-flake]: https://github.com/Hoverbear-Consulting/flake
[nixos-modules]: https://nixos.wiki/wiki/NixOS_modules
[nixos]: https://nixos.org/
[configurable-nix-packages]: /blog/configurable-nix-packages/
[github-nix-extendModules]: https://github.com/NixOS/nixpkgs/blob/4e416a8e847057c49e73be37ae8dc4fcdfe9eff8/lib/modules.nix#L333-L354