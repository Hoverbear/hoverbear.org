+++
title = "WSL"
description = "The so-called Windows Subsystem for Linux."
sort_by = "weight"
template =  "blog/list.html"
insert_anchor_links = "heading"

[extra]
in_menu = true

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Torsten Dederichs"
source = "https://unsplash.com/photos/WRrGflm_Umo"
+++

# Reset WSL2 Quickly

If you're getting `Network Unreachable` in WSL2 for some reason, try this:

```powershell
sudo Disable-WindowsOptionalFeature -Online -FeatureName -NoRestart `
    $("VirtualMachinePlatform", "Microsoft-Windows-Subsystem-Linux")
sudo Enable-WindowsOptionalFeature -Online -FeatureName `
    $("VirtualMachinePlatform", "Microsoft-Windows-Subsystem-Linux")
```

# Systemd in WSL2

It should ['just work'](https://devblogs.microsoft.com/commandline/systemd-support-is-now-available-in-wsl/) now, but sometimes you may need to set something in your `wsl.conf`:

```toml
# /etc/wsl.conf
[boot]
systemd=true
```

# Import WSL2 disks in place

You can just import random `vhdx` disks you have with:

```shell
wsl --import-in-place ubuntu ext4.vhdx
```

You don't need to export them or anything, just getting the `vhdx` is enough.

You can put them generally anywhere, even some random dev drive.

# Sparse WSL2 disks

You can make your WSL2 disks sparse now, saving disk space.

To make a distro sparse:

```shell
wsl --manage $DISTRO $ --set-sparse true
```

Also:

```toml
# ~/.wslconfig

[experimental]
sparseVhd=true
```