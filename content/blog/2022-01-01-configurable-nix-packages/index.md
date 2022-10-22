+++
title = "Configurable Nix packages"
description = "Let your users bring their settings with them."
template =  "blog/single.html"

[taxonomies]
tags = [
    "Nix",
]

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Dylan McLeod"
source = "https://unsplash.com/photos/VRdZBLqnoMU"
+++

The [`vim`][nixpkgs-vim] and [`neovim`][nixpkgs-neovim] packages in [Nixpkgs][nixpkgs] allow users to set custom configuration, including their `customRC` and any plugins they might want.

How do they accomplish it?

In this article, we'll explore how to create packages with similar behavior. We'll create a simple Rust app that consumes a configuration file, then create a Nix flake containing both an unwrapped binary package as well as a configurable package.

<!-- more -->


# Observing our goal {#goal}

My [`neovimConfigured`][neovimConfigured] derivation demonstrates the desired experience for our users:

```nix
{ neovim, vimPlugins }:

neovim.override {
  vimAlias = true;
  viAlias = true;
  configure = {
    customRC = ''
      luafile ${../config/nvim/init.lua}
    '';
    packages.myVimPackage = with vimPlugins; {
      start = [
        LanguageClient-neovim
        # ...
      ];
    };
  };
}
```

We're able to override the `neovim` package with some custom attributes which are then loaded when the `nvim` from that package is invoked. In theory, virtually any Nix user could run the following and get nearly my exact configuration:

```bash
nix run github:hoverbear-consulting/flake#neovimConfigured
```

In order to accomplish this, we'll make use of [`nixpkgs.lib.makeOverridable`][makeOverridable].


# Interacting with `makeOverridable` {#makeOverrideable}

The [`makeOverridable`][makeOverridable] *([source][makeOverridable-src])* function allows us to attach an `override` behavior to a given function.

Let's open our `nix repl` and try it:

```nix
nix-repl> makeOverridable = (builtins.getFlake "nixpkgs").lib.makeOverridable

nix-repl> pretendPkg = args@{ ... }: args

nix-repl> pretendPkg { foo = 1; }
{ foo = 1; }

nix-repl> overriddenPretendPkg = makeOverridable pretendPkg { default = true; }

nix-repl> overriddenPretendPkg
{ default = true; override = { ... }; overrideDerivation = «lambda @ /nix/store/31jbhzh2pj5zsr5ip983qbknv23kf7d4-source/lib/customisation.nix:84:32»; }
```

When we used `makeOverridable` with the `pretendPkg` function it creates a result (`overriddenPretendPkg`) as if the original function was called with the given attribute set (`{ default = true; }`), as well as two additional attributes: `override` and `overrideDerivation`.

Let's check out `override`:

```nix
nix-repl> overriddenPretendPkg.override
{ __functionArgs = { ... }; __functor = «lambda @ /nix/store/31jbhzh2pj5zsr5ip983qbknv23kf7d4-source/lib/trivial.nix:346:19»; }

nix-repl> overriddenPretendPkg.override { }
{ default = true; override = { ... }; overrideDerivation = «lambda @ /nix/store/31jbhzh2pj5zsr5ip983qbknv23kf7d4-source/lib/customisation.nix:84:32»; }

nix-repl> overriddenPretendPkg.override { default = false; }
{ default = false; override = { ... }; overrideDerivation = «lambda @ /nix/store/31jbhzh2pj5zsr5ip983qbknv23kf7d4-source/lib/customisation.nix:84:32»; }
```

So `override` is a function which accepts an attribute set which it merges with the attribute set the `makeOverride` function is invoked with.

> Note: **[`overrideDerivation`][overrideDerivation] is deprecated**, so we won't discuss it.

We can use `makeOverridable` on **any function** that accepts an attribute set, namely, a Nix package created through something like `mkDerivation` or `mkShell`.

Let's make a quick Rust application, after, we can make a Nix flake, package, and overridable package for it!


# A test application {#rust}

First, let's quickly bootstrap a Rust package to play with. Make a `demo` directory and create the following two files:

{{ code_file(path="demo/Cargo.toml", code_lang="toml", colocated=true, show_path_with_prefix="#") }}

{{ code_file(path="demo/src/main.rs", code_lang="rust", colocated=true, show_path_with_prefix="//") }}

This will create a program which accepts a given config, loads it, and prints it out to `stdout`. That should be sufficient to tell if we've succeeded in our task later!

If you already have a global Rust environment set up, you can give this a test with `cargo run` or `DEMO_CONFIG=/some/path cargo run`. If you don't have one, you'll be able to do this after the next step.


# Flexing Nix {#nix}

Now our little crate needs a Nix package. We'll use [`github:oxalica/rust-overlay`][oxalica-rust-overlay] and [`github:nix-community/naersk`][nix-community-naersk] today, so our `demo` crate is built like so:

```nix
# Chunk of a Flake.nix
overlay = final: prev: {
  demo-unwrapped = naersk.lib."${final.hostPlatform.system}".buildPackage rec {
    pname = "demo";
    version = "0.0.1";
    src = gitignore.lib.gitignoreSource ./.;
  };
  # ...
```

> Note: We suffix it with `-unwrapped` so the configurable package can be `demo`. We call it 'unwrapped' since we will be 'wrapping' the package to make it configurable.

Then we'll define a `wrapDemo` function which takes some given non-overridable `demo` package and makes it overridable.

```nix
wrapDemo = demo-unwrapped: final.lib.makeOverridable ({ configuration ? null }:
  if configuration == null then
    demo-unwrapped
  else
    let
      configurationFile = final.writeTextFile {
        name = "demo-config";
        text = configuration;
      }; in
    final.symlinkJoin {
      name = "demo-${final.lib.getVersion final.demo-unwrapped}";
      paths = [ ];
      nativeBuildInputs = with final; [ makeWrapper ];
      postBuild = ''
        makeWrapper ${demo-unwrapped}/bin/demo \
          ${placeholder "out"}/bin/demo \
          --set-default DEMO_CONFIG ${configurationFile}
      '';
    });
```

The `{ configuration ? null }` (on the first line) is the available options to override, here you could add, remove, or change what users can manipulate.

[`symlinkJoin`][symlinkJoin] ([source][symlinkJoin-src]) is a builder like `mkDerivation`, and produces what `nix run` (and the rest) expect.

The `placeholder` function, a [Nix builtin][nix-builtins], returns a placeholder for one of the [outputs][nix-multiple-outputs] of a package.

In the `postBuild` step of the derivation we'll make use of [`makeWrapper`][makeWrapper] ([source][makeWrapper-src]), which allows us to do things like set arguments and populate environment variables.

With that, we can define the 'wrapped' package:

```nix
demo = final.wrapDemo final.demo-unwrapped { };
```

So whole flake looks like so:

{{ code_file(path="demo/flake.nix", code_lang="nix", colocated=true, show_path_with_prefix="#") }}

If you use `direnv` you can add this too:

{{ code_file(path="demo/.envrc", code_lang="bash", colocated=true, show_path_with_prefix="#") }}

{{ figure(path="experiment.jpg", alt="A scientist doing an experiment.", colocated=true, source="https://unsplash.com/photos/JxoWb7wHqnA", photographer="@nci") }}

# Experimenting {#test}

Let's validate that this works!

In our `Flake.nix` we also defined a `demoConfigured` package which uses `override` and sets a custom `configuration`:

```nix
packages = forAllSystems (system:
  let
    pkgs = pkgsForSystem system;
  in
  {
    inherit (pkgs) demo demo-unwrapped;
    demoConfigured = pkgs.demo.override {
      configuration = ''
        switch = true
      '';
    };
  });
```

We can run it as well as the default `demo` and validate the configuration file does get overriden:

```bash
$ nix run .#demo
CliArgs {
    config: "/etc/demo.toml",
}
Error: 
   0: Failed to open config /etc/demo.toml
   1: No such file or directory (os error 2)

Backtrace omitted.
Run with RUST_BACKTRACE=1 environment variable to display it.
Run with RUST_BACKTRACE=full to include source snippets.
```

Now the configured one:

```bash
$ nix run .#demoConfigured
CliArgs {
    config: "/nix/store/9q4hmdspzh4riga0k3xsy1zsg2s33q09-demo-config",
}
Config {
    switch: true,
}
```

Fantastic! We can see `switch` got set in our `demoConfigured` package, and the config file it reads from is part of our Nix store.

As you can see, Nix lets us make configurable wrappers around our packages quite easily, allowing your users to take their configuration with them.

[nix-multiple-outputs]: https://nixos.org/manual/nixpkgs/stable/#chap-multiple-output
[nix-builtins]: https://nixos.org/manual/nix/stable/expressions/builtins.html
[nixpkgs]: https://github.com/NixOS/nixpkgs
[nixpkgs-neovim]: https://github.com/NixOS/nixpkgs/tree/98f82e9c35aaf1eb32f0d8787e948da5ca970449/pkgs/applications/editors/neovim
[nixpkgs-vim]: https://github.com/NixOS/nixpkgs/tree/98f82e9c35aaf1eb32f0d8787e948da5ca970449/pkgs/applications/editors/vim
[neovimConfigured]: https://github.com/Hoverbear-Consulting/flake/blob/57ccc6aae264c6000017483d34783464cd393f4e/packages/neovim.nix
[makeOverridable]: https://nixos.org/manual/nixpkgs/stable/#sec-lib-makeOverridable
[makeOverridable-src]: https://github.com/NixOS/nixpkgs/blob/98f82e9c35aaf1eb32f0d8787e948da5ca970449/lib/customisation.nix#L49-L93
[symlinkJoin]: https://nixos.org/manual/nixpkgs/stable/#trivial-builder-symlinkJoin
[symlinkJoin-src]: https://github.com/NixOS/nixpkgs/blob/b487ccf50099eee2da77227d9fb99c84cc90a0c7/pkgs/build-support/trivial-builders.nix#L325-L391
[overrideDerivation]: https://nixos.org/manual/nixpkgs/stable/#sec-pkg-overrideDerivation
[makeWrapper]: https://nixos.org/manual/nixpkgs/stable/#fun-makeWrapper
[makeWrapper-src]: https://github.com/NixOS/nixpkgs/blob/ba09908b2c15c40f5c0c3d11ebe6c1d6c440a9ce/pkgs/build-support/setup-hooks/make-wrapper.sh
[oxalica-rust-overlay]: https://github.com/oxalica/rust-overlay
[nix-community-naersk]: https://github.com/nix-community/naersk