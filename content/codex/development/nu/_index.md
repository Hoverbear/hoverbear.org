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

# Installing 

Developing across multiple operating systems can be pretty annoying! Mac `bash` is different than Arch `bash`, which is different than Windows `powershell`. 😵‍💫

We can use `nu` to bring some consistency.

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

# Motivations

## Consistent Builtins

Things like `cp`, `rm`, and `ls` work consistently on `nu`. (Here's looking at `rm -rf` on Powershell...)

## 

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