+++
title = "A Flake for your Crate"
description = "Creating a Nix Flake for your Rust crate."
template =  "blog/single.html"

[taxonomies]
tags = [
"Nix",
]

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Ahmed Sobah"
source = "https://unsplash.com/photos/Cbo4Bxx7SaA"
+++

[Nix (PDF)](https://edolstra.github.io/pubs/phd-thesis.pdf) provides users a way to access the massive [Nixpkgs](https://github.com/NixOS/nixpkgs) library of packages, create reproducable buildss of software, roll slim containers, create declarative VMs, or run their whole machines. A new feature of Nix, *Flakes*, is bringing a convention to how projects like Rust crates can be accessed, integrated, and used within Nix (or NixOS.)

Let's explore how we can make our Rust crate usable as a Nix flake. At the end of this, any `nix` user with Flakes enabled should be able to run your project with something like `nix run github:user/project`. They'll be able to add your repository as a [Nix overlay](https://nixos.wiki/wiki/Overlays), install the package, do interactive builds, or create a portable bundle of it.

<!-- more -->

# Prerequisites

Before we get started, you'll need a Nix with the `flakes` feature enabled. Let's do that!

## If using [NixOS](https://nixos.wiki/wiki/NixOS):

```nix
{
  # Use edge NixOS.
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
  nix.package = pkgs.nixUnstable;

  nixpkgs.config.allowUnfree = true;
}
```

Then do a `nixos-rebuild switch` to activate it. You may also want to enable [`nix-direnv`](https://github.com/nix-community/nix-direnv#via-configurationnix-in-nixos).

## If using [Nix](https://nixos.org/manual/nix/unstable/introduction.html)


```bash
mkdir -p ~/.config/nix/
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
nix-env -iA nixpkgs.nixUnstable
```

You may also want to enable [`nix-direnv`](https://github.com/nix-community/nix-direnv#with-nix-env).

# Setup

For this article, I'll create a new crate. You can use your existing crate! You should also ensure it's a Git repository. (Flakes require this!)

```rust
cargo init scratch
cd scratch
nvim Cargo.toml
// Add a `description = "boop"` field under `[package]`!

git init
git add src/ Cargo.toml
```

## `flake.nix`

Next, we'll create a `flake.nix`. This is the coarse equivalent of a `Cargo.toml` file in Rust. (In fact, later we'll even see a `flake.lock`, just like Cargo!)

[Flakes](https://nixos.wiki/wiki/Flakes) are a Nix file with a predetermined schema. The [wiki page](https://nixos.wiki/wiki/Flakes#Flake_schema) includes a schema.

Our flake will have three items in the root:

* **`description`:** A string description of the flake. Consider making this your crate description!
* **`inputs`:** The inputs required by the flake. Generally `nixpkgs` and `naersk` (for the fancy Rust builder) will be enough.
* **`outputs`:** A function accepting the (realized) inputs, returning the outputs of the flake, such as packages, NixOS modules, or library items!

The first two are pretty self explanatory, let's dig into outputs! We only use a few of the available options:

* **`overlay`:** A [Nix overlay](https://nixos.wiki/wiki/Overlays) which can have package definitions added. Can be added to Nix systems to allow adding items to the environment (such as via `environment.systemPackages`.)
* **`packages`:** A set of packages one could invoke with `nix run $FLAKE#packageName` or build with `nix build $FLAKE#packageName`.
* **`defaultPackage`:** The default item to run/build when `nix run $FLAKE` or `nix build $FLAKE` is invoked.
* **`checks`:** A set of checks (think like `cargo fmt`) to run whenever `nix flake check` is run. This is particularly useful for pre-commit hooks or CI.
* **`devShell`:** An environment for when `nix develop` is run. This is also used in `nix-direnv`.

You shouldn't need to make many changes to this file, **but you should customize the `description` and remove any platforms you don't support**.

```nix
# flake.nix
{
  description = "My cute Rust crate!";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    naersk.url = "github:nmattia/naersk";
    naersk.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, naersk }:
    let
      cargoToml = (builtins.fromTOML (builtins.readFile ./Cargo.toml));
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in
    {
      overlay = final: prev: {
        "${cargoToml.package.name}" = final.callPackage ./. { inherit naersk; };
      };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              self.overlay
            ];
          };
        in
        {
          "${cargoToml.package.name}" = pkgs."${cargoToml.package.name}";
        });


      defaultPackage = forAllSystems (system: (import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      })."${cargoToml.package.name}");

      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              self.overlay
            ];
          };
        in
        {
          format = pkgs.runCommand "check-format"
            {
              buildInputs = with pkgs; [ rustfmt cargo ];
            } ''
            ${pkgs.rustfmt}/bin/cargo-fmt fmt --manifest-path ${./.}/Cargo.toml -- --check
            ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
            touch $out # it worked!
          '';
          "${cargoToml.package.name}" = pkgs."${cargoToml.package.name}";
        });
      devShell = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ self.overlay ];
          };
        in
        pkgs.mkShell {
          inputsFrom = with pkgs; [
            pkgs."${cargoToml.package.name}"
          ];
          buildInputs = with pkgs; [
            rustfmt
            nixpkgs-fmt
          ];
          LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
        });
    };
}

```

Then `git add flake.nix`.

## `default.nix`

This file is specific to our crate! It is a Nix package. Let's break it down, top to bottom:

* **The Inputs (`{ the, stuff, here }:`):** This list of function arguments represents all of the inputs into the
  expression.
* **A `let ... in` binding:** Here we set a variable which when accessed evaluates the `Cargo.toml`.
* **A `naersk` call:** [`naersk`](https://github.com/nmattia/naersk) is an improvement over the
  [`nixpkgs.buildRustPackage`](https://nixos.org/manual/nixpkgs/stable/#rust) traditionally available.
* **A `src` location:** This

```nix
# default.nix
{ lib
, naersk
, stdenv
, clangStdenv
, hostPlatform
, targetPlatform
, pkg-config
, libiconv
, rustfmt
, cargo
, rustc
  # , llvmPackages # Optional
  # , protobuf     # Optional
}:

let
  cargoToml = (builtins.fromTOML (builtins.readFile ./Cargo.toml));
in

naersk.lib."${targetPlatform.system}".buildPackage rec {
  src = ./.;

  buildInputs = [
    rustfmt
    pkg-config
    cargo
    rustc
    libiconv
  ];
  checkInputs = [ cargo rustc ];

  doCheck = true;
  CARGO_BUILD_INCREMENTAL = "false";
  RUST_BACKTRACE = "full";
  copyLibs = true;

  # Optional things you might need:
  #
  # If you depend on `libclang`:
  # LIBCLANG_PATH = "${llvmPackages.libclang}/lib";
  #
  # If you depend on protobuf:
  # PROTOC = "${protobuf}/bin/protoc";
  # PROTOC_INCLUDE = "${protobuf}/include";

  name = cargoToml.package.name;
  version = cargoToml.package.version;

  meta = with lib; {
    description = cargoToml.package.description;
    homepage = cargoToml.package.homepage;
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ ];
  };
}

```

Then `git add default.nix`.

> While you could *technically* moosh these together, I think it's much nicer to keep them separate.

## Optional: `nix-direnv` & `.envrc`

In order to hook into [`nix-direnv`](https://github.com/nix-community/nix-direnv):

```bash
echo "use flake" > .envrc
direnv reload
```

Then `git add .envrc`.

# Make sure it works

Before we do a full proper build, we need to populate the `Cargo.lock`! (Skip this if you have one!)

> If you did not opt to use `nix-direnv`, now you need to call `nix develop .` to enter the full development shell.

```bash
cargo fetch
git add Cargo.lock
```

At this point you can try out `cargo build` and other relevant commands. They should work and use the libraries and tools provided by Nix.

```bash
cargo check
cargo build
cargo run --release
```


Go ahead and test a build:

```bash
# Precautionary formatting...
nixpkgs-fmt ./.

nix flake check
nix build .
nix run .
```

> Get trouble? Try running `nix build --print-build-logs --keep-failed` to be able to see logs and check the workdir.

Here's it working:

```bash
$ nix run .
Hello, world!
```

# In the real world

So how does this do on other crates? I test these files to several other popular Rust packages, here's what I needed to change for each:

### [`ripgrep`](https://github.com/BurntSushi/ripgrep)

I had to set `mainProgram` within the `meta` of `default.nix`:

```nix
# default.nix
{ /* ... */ }:
{
  # ...
  meta = with lib; {
    # ...
    mainProgram = "rg";  
  };
} 
```
### [`bottom`](https://github.com/ClementTsang/bottom)

I also had to set `mainProgram` to `btm`. I also had to set `doCheck = true` in `default.nix`, as the tests depended on floating environment variables the build didn't have.

```nix
# default.nix
{ /* ... */ }:
{
  # ...
  doCheck = false;
  meta = with lib; {
    # ...
    mainProgram = "btm";  
  };
} 
```
### [Nushell (`nu`)](https://github.com/nushell/nushell)

`nu` uses *recursive git dependencies* which are an issue for Naersk right now ([#162](https://github.com/nmattia/naersk/issues/162)), so I had to 'lift' those dependencies into the `Cargo.toml` as plain dependencies (with `git` and `rev` attributes):

```toml
# Cargo.toml
# ...

[dependencies]
arrow = { git = "https://github.com/apache/arrow-rs", rev = "9f56afb2d2347310184706f7d5e46af583557bea" }
```
In addition, I had to add `openssl` to the `buildInputs` in `default.nix`, and I set `doCheck = false` because some tests weren't able to touch certain places on the filesystem. Finally, like the others, I had to set `mainProgram`.

```nix
# default.nix
{ /* ... */, openssl }:
{
  # ...
  buildInputs = with pkgs; [
    # ...
    openssl
  ];
  doCheck = false;
  meta = with lib; {
    # ...
    mainProgram = "nu";  
  };
}
```

# Getting help

For general help with Nix, consult [the forums](https://discourse.nixos.org/), for help with Rust try [the forums](https://users.rust-lang.org/).

I also find [nix.dev](https://nix.dev/), [nixos.wiki](https://nixos.wiki/), and [the `nixUnstable` manual](https://nixos.org/manual/nix/unstable/introduction.html) very helpful.

**Need something more personal?**

These days my consultancy is working with Indigenous organizations or persons. If you call into one of those categories, please contact me at [*consulting@hoverbear.org*](mailto:consulting@hoverbear.org).

If you're a tech startup, or anyone else, I would love to recommend you to use the services of [Determinate Systems](https://determinate.systems/) for Nix problems, and [Ferrous Systems](https://ferrous-systems.com/) for Rust problems. They are owned and operated by people I trust.