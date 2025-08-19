+++
title = "Windows"
description = "A fickle, proprietary, fragile, expensive monstrosity."
sort_by = "weight"
template =  "blog/list.html"
insert_anchor_links = "heading"

[extra]
in_menu = true

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Roseanna Smith"
source = "https://unsplash.com/photos/-qzLjuJEmsE"
+++

<!-- more -->

# Get `sudo`

You can get [`sudo` working via the "Use Developer Features"](https://learn.microsoft.com/en-us/windows/advanced-settings/sudo/) hook in the Start Menu. Look for a shield called "Enable Sudo".

It's... just okay.

# Use a Package Manager

Use `winget` if you can!

## Use Nushell

```powershell
winget install Nushell.Nushell
```

## Git

Git on Windows is a... 'special' flower.

```powershell
winget install Git.Git
```

On big clones errors like this are common:

```powershell
$ git clone --recurse-submodules -j16 git@github.com:boop/droop.git
Cloning into 'droop'...
remote: Enumerating objects: 2673758, done.
remote: Counting objects: 100% (49873/49873), done.
remote: Compressing objects: 100% (14594/14594), done.
fetch-pack: unexpected disconnect while reading sideband packetB/s
fatal: fetch-pack: invalid index-pack output
```

Pass `--depth 1` to improve the chance it might succeed. Then:

```powershell
git fetch --unshallow
```

# Disable Recall

From an administrator terminal:

```powershell
Dism /Online /Disable-Feature /Featurename:Recall
```

# Disable Start Menu's Bing searches

To disable the Bing searches in the start menu when you start typing (and thus only search the local machine):

```powershell
powershell -c 'Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Search -Name "DisableSearchBoxSuggestions" -Value 1 -Type DWord'
```