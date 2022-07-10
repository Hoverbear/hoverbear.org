+++
title = "Using rust-bindgen in Nix"
description = "Getting things linking."
template =  "blog/single.html"

[taxonomies]
tags = [
    "Nix",
]

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "James Bruce"
source = "https://unsplash.com/photos/4XS-RtLwS_0"
+++

While building the Nix packages for [pl/Rust][repo-plrust] I bumped into a curious issue: I couldn't link to `stdio.h`, or `stdbool.h`! They were clearly on my path, too.

It flummoxed me for quite some time, but exploring the [`firefox`][pkgs-firefox-bindgen] package led to a way forward. It was [`rust-bindgen`][repo-rust-bindgen] not finding libraries!

<!-- more -->

# Why `rust-bindgen` fails

In my case, there were multiple problems, but the problem solving of the first issue lead to me being able to handle the second much easier.

## Missing paths from `gcc-wrapper`

Bindgen uses [`libclang`][docs-libclang] instead of calling `$CC`. This means it interacts poorly which NixOS, whose `rustPlatform.buildRustPackage` sets a `$CC` for `rustc` to use.

You can see on the last line here:

```bash
$ nix build --print-build-logs
# ...
doggo> Executing cargoBuildHook
doggo> ++ env CC_x86_64-unknown-linux-gnu=/nix/store/zzvq5qwlm2xikawfqxb0q8gl2bw391a9-gcc-wrapper-10.2.0/bin/cc CXX_x86_64-unknown-linux-gnu=/nix/store/zzvq5qwlm2xikawfqxb0q8gl2bw391a9-gcc-wrapper-10.2.0/bin/c++ CC_x86_64-unknown-linux-gnu=/nix/store/zzvq5qwlm2xikawfqxb0q8gl2bw391a9-gcc-wrapper-10.2.0/bin/cc CXX_x86_64-unknown-linux-gnu=/nix/store/zzvq5qwlm2xikawfqxb0q8gl2bw391a9-gcc-wrapper-10.2.0/bin/c++ cargo build -j 32 --target x86_64-unknown-linux-gnu --frozen --release
```

This means when `rust-bindgen` runs, it doesn't have knowledge about all those paths it *probably maybe should* have as provided by the [`gcc-wrapper`][pkgs-cc-wrapper-libc-support].

The `gcc-wrapper` derivation includes several support files in `$out/nix-support` we can utilize to work around this problem.


## Additional paths

The libraries from `gcc-wrapper` aren't always enough though. It's common to need additional libraries, such as something like `stddef.h` which is available in the `gcc` includes.

In these cases, we can often find the pathes of the relevant libraries by looking at the output from `cpp -v /dev/null -o /dev/null` (as recommended by the [`gcc` docs][docs-gcc-search-path]) in the `preBuild` phase, and investigating `nix build .#doggo --print-build-logs`:

```nix
rustPlatform.buildRustPackage rec {
  # ...
  preBuild = ''
    cpp -v /dev/null -o /dev/null
  '';
  # ...
}
```

That would output a list of paths you could search to find the relevant header:

```bash
$ nix build .#doggo --print-build-logs
# ...
doggo> #include "..." search starts here:
doggo> #include <...> search starts here:
doggo>  /nix/store/q8rv03yvqsfipnxwyj0sb6lqs50y5b3q-gcc-10.2.0/lib/gcc/x86_64-unknown-linux-gnu/10.2.0/include
doggo>  /nix/store/q8rv03yvqsfipnxwyj0sb6lqs50y5b3q-gcc-10.2.0/include
doggo>  /nix/store/q8rv03yvqsfipnxwyj0sb6lqs50y5b3q-gcc-10.2.0/lib/gcc/x86_64-unknown-linux-gnu/10.2.0/include-fixed
doggo>  /nix/store/vr4977307zkjprfkivi4lgbzlvig3y9j-glibc-2.32-40-dev/include
doggo> End of search list.
```

Once you've found the path, you can 'nixify' it into something like this:

```nix
# This:
/nix/store/q8rv03yvqsfipnxwyj0sb6lqs50y5b3q-gcc-10.2.0/lib/gcc/x86_64-unknown-linux-gnu/10.2.0/include
# Into:
${stdenv.cc.cc}/lib/gcc/${stdenv.hostPlatform.config}/${lib.getVersion stdenv.cc.cc}/include
```

You'll be able to add that path in later.

# What to do about it

While chatting with the clever [Hazel Weakly][hazel-weakly] we noticed that we could tell `rust-bindgen` about these `CFLAGS` via [`BINDGEN_EXTRA_CLANG_ARGS`][docs-rust-bindgen-cflags]

What we gleaned from the [`firefox`][pkgs-firefox-bindgen] was to add something like this to the `preBuild`:

```nix
rustPlatform.buildRustPackage rec {
  preBuild = ''
    # From: https://github.com/NixOS/nixpkgs/blob/1fab95f5190d087e66a3502481e34e15d62090aa/pkgs/applications/networking/browsers/firefox/common.nix#L247-L253
    # Set C flags for Rust's bindgen program. Unlike ordinary C
    # compilation, bindgen does not invoke $CC directly. Instead it
    # uses LLVM's libclang. To make sure all necessary flags are
    # included we need to look in a few places.
    export BINDGEN_EXTRA_CLANG_ARGS="$(< ${stdenv.cc}/nix-support/libc-crt1-cflags) \
      $(< ${stdenv.cc}/nix-support/libc-cflags) \
      $(< ${stdenv.cc}/nix-support/cc-cflags) \
      $(< ${stdenv.cc}/nix-support/libcxx-cxxflags) \
      ${lib.optionalString stdenv.cc.isClang "-idirafter ${stdenv.cc.cc}/lib/clang/${lib.getVersion stdenv.cc.cc}/include"} \
      ${lib.optionalString stdenv.cc.isGNU "-isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc} -isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc}/${stdenv.hostPlatform.config}"}
    "
  '';
}
```

For my additional path (`stddef.h` from `${stdenv.cc.cc}/lib/gcc/${stdenv.hostPlatform.config}/${lib.getVersion stdenv.cc.cc}/include`) I changed the last line of the export to include it with an `-idirafter` flag:

```nix
# ...
${lib.optionalString stdenv.cc.isGNU "-isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc} -isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc}/${stdenv.hostPlatform.config} -idirafter ${stdenv.cc.cc}/lib/gcc/${stdenv.hostPlatform.config}/${lib.getVersion stdenv.cc.cc}/include"}
# ...
```

# Worked Example

Let's work this example to make sure it's true!

## Files

Create some files in a scratch directory:

```nix
# flake.nix
{
  description = "A bindgen demo.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
    in
    {
      defaultPackage = forAllSystems (system: (import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      }).doggo);

      overlay = final: prev: {
        doggo = final.callPackage ./. { };
      };
    };
}
```

```nix
# default.nix
{ lib
, rustPlatform
, stdenv
, hostPlatform
, llvmPackages
}:

let
    cargoToml = (builtins.fromTOML (builtins.readFile ./Cargo.toml));
in
rustPlatform.buildRustPackage rec {
  pname = cargoToml.package.name;
  version = cargoToml.package.version;

  src = ./.;

  #cargoSha256 = lib.fakeSha256;
  cargoSha256 = "k7SDJdjHa5oqgi173aRZcLbBsQcc7ohJqiK7zY2HMP8=";

  LIBCLANG_PATH = "${llvmPackages.libclang}/lib";
  doCheck = false;

  preBuild = ''
    # From: https://github.com/NixOS/nixpkgs/blob/1fab95f5190d087e66a3502481e34e15d62090aa/pkgs/applications/networking/browsers/firefox/common.nix#L247-L253
    # Set C flags for Rust's bindgen program. Unlike ordinary C
    # compilation, bindgen does not invoke $CC directly. Instead it
    # uses LLVM's libclang. To make sure all necessary flags are
    # included we need to look in a few places.
    export BINDGEN_EXTRA_CLANG_ARGS="$(< ${stdenv.cc}/nix-support/libc-crt1-cflags) \
      $(< ${stdenv.cc}/nix-support/libc-cflags) \
      $(< ${stdenv.cc}/nix-support/cc-cflags) \
      $(< ${stdenv.cc}/nix-support/libcxx-cxxflags) \
      ${lib.optionalString stdenv.cc.isClang "-idirafter ${stdenv.cc.cc}/lib/clang/${lib.getVersion stdenv.cc.cc}/include"} \
      ${lib.optionalString stdenv.cc.isGNU "-isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc} -isystem ${stdenv.cc.cc}/include/c++/${lib.getVersion stdenv.cc.cc}/${stdenv.hostPlatform.config} -idirafter ${stdenv.cc.cc}/lib/gcc/${stdenv.hostPlatform.config}/${lib.getVersion stdenv.cc.cc}/include"} \
    "
  '';

  meta = with lib; {
    description = cargoToml.package.description;
    homepage = cargoToml.package.homepage;
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ hoverbear ];
  };
}
```

```c
// wrapper.h
#include "doggo.h"
#include <stdio.h>
```

```c
// doggo.h
typedef struct Doggo {
    int breed;
} Doggo;
```

```toml
# Cargo.toml
[package]
name = "doggo"
description = "A demo."
homepage = "hoverbear.org"
version = "0.1.0"
authors = ["Ana Hobden <operator@hoverbear.org>"]
edition = "2018"

[dependencies]

[build-dependencies]
bindgen = "0.53.1"
```

```rust
// src/main.rs
include!(concat!(env!("OUT_DIR"), "/bindings.rs"));

fn main() {
    println!("Hello, world {:?}!", Doggo {
        breed: 1,
    });
}
```

```rust
// build.rs
extern crate bindgen;

use std::env;
use std::path::PathBuf;

fn main() {
    println!("cargo:rerun-if-changed=wrapper.h");
    let bindings = bindgen::Builder::default()
        .header("wrapper.h")
        .parse_callbacks(Box::new(bindgen::CargoCallbacks))
        .generate()
        .expect("Unable to generate bindings");
    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings!");
}
```

## Working output

Running `nix build --print-build-logs` should output something like:

```
$ nix build --print-build-logs --rebuild
warning: Git tree '/home/ana/scratch' is dirty
doggo> unpacking sources
doggo> unpacking source archive /nix/store/xwxksd08px6pmhxwq0wh09hsva51smf7-4bcjjs5zg4mxzhs9qrcz2rjf8ck5wvp1-source
doggo> source root is 4bcjjs5zg4mxzhs9qrcz2rjf8ck5wvp1-source
doggo> Executing cargoSetupPostUnpackHook
doggo> unpacking source archive /nix/store/isna8kr86v18plg2ln91i6n85pm2v7cw-doggo-0.1.0-vendor.tar.gz
doggo> Finished cargoSetupPostUnpackHook
doggo> patching sources
doggo> Executing cargoSetupPostPatchHook
doggo> Validating consistency between /build/4bcjjs5zg4mxzhs9qrcz2rjf8ck5wvp1-source//Cargo.lock and /build/doggo-0.1.0-vendor.tar.gz/Cargo.lock
doggo> Finished cargoSetupPostPatchHook
doggo> configuring
doggo> building
doggo> Executing cargoBuildHook
doggo> ++ env CC_x86_64-unknown-linux-gnu=/nix/store/zzvq5qwlm2xikawfqxb0q8gl2bw391a9-gcc-wrapper-10.2.0/bin/cc CXX_x86_64-unknown-linux-gnu=/nix/store/zzvq5qwlm2xikawfqxb0q8gl2bw391a9-gcc-wrapper-10.2.0/bin/c++ CC_x86_64-unknown-linux-gnu=/nix/store/zzvq5qwlm2xikawfqxb0q8gl2bw391a9-gcc-wrapper-10.2.0/bin/cc CXX_x86_64-unknown-linux-gnu=/nix/store/zzvq5qwlm2xikawfqxb0q8gl2bw391a9-gcc-wrapper-10.2.0/bin/c++ cargo build -j 32 --target x86_64-unknown-linux-gnu --frozen --release
# ...
doggo>     Finished release [optimized] target(s) in 9.44s
doggo> Executing cargoInstallPostBuildHook
doggo> Finished cargoInstallPostBuildHook
doggo> Finished cargoBuildHook
doggo> installing
doggo> Executing cargoInstallHook
doggo> Finished cargoInstallHook
doggo> post-installation fixup
doggo> shrinking RPATHs of ELF executables and libraries in /nix/store/yl3z0gaw618wmzxzn57hyx578lfi3sqz-doggo-0.1.0
doggo> shrinking /nix/store/yl3z0gaw618wmzxzn57hyx578lfi3sqz-doggo-0.1.0/bin/doggo
doggo> strip is /nix/store/5xyjd2qiily84lcv2w2grmwsb8r1hqpr-binutils-2.35.1/bin/strip
doggo> stripping (with command strip and flags -S) in /nix/store/yl3z0gaw618wmzxzn57hyx578lfi3sqz-doggo-0.1.0/bin
doggo> patching script interpreter paths in /nix/store/yl3z0gaw618wmzxzn57hyx578lfi3sqz-doggo-0.1.0
doggo> checking for references to /build/ in /nix/store/yl3z0gaw618wmzxzn57hyx578lfi3sqz-doggo-0.1.0..
```

## Reproducing the issue

To reproduce the issue, try removing the `preBuild` step from the `default.nix` you created:

```
doggo>    Compiling doggo v0.1.0 (/build/kihmwg0msazwl8x84yahp73k1jn816d9-source)
doggo> error: failed to run custom build command for `doggo v0.1.0 (/build/kihmwg0msazwl8x84yahp73k1jn816d9-source)`
doggo> Caused by:
doggo>   process didn't exit successfully: `/build/kihmwg0msazwl8x84yahp73k1jn816d9-source/target/release/build/doggo-12463103eef102f1/build-script-build` (exit code: 101)
doggo>   --- stdout
doggo>   cargo:rerun-if-changed=wrapper.h
doggo>   --- stderr
doggo>   wrapper.h:2:10: fatal error: 'stdio.h' file not found
doggo>   wrapper.h:2:10: fatal error: 'stdio.h' file not found, err: true
doggo>   thread 'main' panicked at 'Unable to generate bindings: ()', build.rs:12:10
doggo>   note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
error: builder for '/nix/store/kb7rc2hv289gbd9blfviiirzmcra7cm3-doggo-0.1.0.drv' failed with exit code 101;
       last 10 log lines:
       > Caused by:
       >   process didn't exit successfully: `/build/kihmwg0msazwl8x84yahp73k1jn816d9-source/target/release/build/doggo-12463103eef102f1/build-script-build` (exit code: 101)
       >   --- stdout
       >   cargo:rerun-if-changed=wrapper.h
       >
       >   --- stderr
       >   wrapper.h:2:10: fatal error: 'stdio.h' file not found
       >   wrapper.h:2:10: fatal error: 'stdio.h' file not found, err: true
       >   thread 'main' panicked at 'Unable to generate bindings: ()', build.rs:12:10
       >   note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace
       For full logs, run 'nix log /nix/store/kb7rc2hv289gbd9blfviiirzmcra7cm3-doggo-0.1.0.drv'.
```

If you try removing `#include <stdio.h>` from the `wrapper.h` this error will be resolved, but your program will likely want `stdio.h`.

Whew! That's it! Writing about this really helped me sort it out in my head better! Thanks for reading!

[pkgs-firefox-bindgen]: https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/browsers/firefox/common.nix#L247-L253
[pkgs-cc-wrapper-libc-support]: https://github.com/NixOS/nixpkgs/blob/54d0d2b43b5d0b7ee21c30a99012162ecab3f931/pkgs/build-support/cc-wrapper/default.nix#L323-L377
[repo-plrust]: https://github.com/zombodb/plrust
[repo-rust-bindgen]: https://github.com/rust-lang/rust-bindgen
[docs-libclang]: https://clang.llvm.org/doxygen/group__CINDEX.html
[docs-gcc-search-path]: https://gcc.gnu.org/onlinedocs/cpp/Search-Path.html
[hazel-weakly]: https://hazelweakly.me/
[docs-rust-bindgen-cflags]: https://github.com/rust-lang/rust-bindgen#environment-variables
