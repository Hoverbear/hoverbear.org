+++
title = "A Nu Shell"
description = "Finding some consistency on interacting with the machine."
sort_by = "weight"
template =  "blog/list.html"

[extra]
in_menu = true

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Brandon Jaramillo"
source = "https://unsplash.com/photos/white-rose-in-close-up-photography-NzMzETo-XJE"
+++


<!-- more -->

# Motivations

## Cross Platform Consistency

Developing across multiple operating systems can be pretty annoying! Mac `bash` is different than Arch `bash`, which is different than Windows `powershell`. 😵‍💫

Mac defaults to `zsh`, but also packs an old `bash` (usually 3.2). Windows packs Powershell (usually 4, maybe 7), sometimes a msys or mingw or Git `bash`, and `CMD.exe`. Meanwhile Linux can pack... well, a lot of different things.

This means things like `&>` might work on some platforms, but not on others.

It also means things like `cp`, `rm`, and `ls` work consistently on `nu`. (Here's looking at `rm -rf` on Powershell, setting `touch` with timestamps on Mac vs Linux...)

# Configuration



# Installing 

With a Rust toolchain:

```sh
cargo install nu
```

Without a Rust toolchain:

```sh
# Windows
winget install nu
# Mac
brew install nu
# Arch Linux
pacman -S nu
```


# Working with it

[Coming from Bash](https://www.nushell.sh/book/coming_from_bash.html) is quite helpful.

`nu` works slightly differently than other shells in that it separates parsing and evaluation. More in [How Nushell Code Gets Run](https://www.nushell.sh/book/how_nushell_code_gets_run.html).

## Piping to Files

`nu` doesn't have a `>` pipe. Instead:

```nu
cat floof | save boop
```

For `>>`:

```nu
cat floof | save -a boop
```

## Loops

Loops differ syntactically from `bash` in several ways.

For example, unpacking all the archives in the parent directory into the current directory:

```nu
for archive in (ls .. | where type != dir) { tar xvf $archive.name }
```

Similar, but unarchiving into named directories:


```nu
for archive in (ls | where type != dir) {
    let archive_stem = $archive.name | path parse | get stem
    mkdir $archive_stem
    cd $archive_stem
    let archive_path = ".." | path join $archive.name
    tar xvf $archive_path
    cd ..
}
```

## Parameter Expansion

Different shells approach [parameter expansion](https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html) differently.

In `bash` we can do like:

```bash
./x.py --stage 2 dist $(ferrocene/ci/split-tasks.py dist)
```

While `fish` it looks like:

```fish
./x.py --stage 2 dist $(ferrocene/ci/split-tasks.py dist | string split " ")
```

On `nu` we do this:

```nu
./x.py --stage 2 dist ...(python ferrocene/ci/split-tasks.py dist | split row " ")
```