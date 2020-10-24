+++
title = "WSL"
description = "The so-called Windows Subsystem for Linux."
sort_by = "weight"
template = "blog/list.html"

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

# Use Docker in WSL2

There are a few ways to get Docker working.

* A hack such as [this one](https://hoverbear.org/blog/getting-the-most-out-of-wsl/#get-systemd-functional).
* The Docker Desktop WSL2 integration option.

If you only need Docker to work, I strongly suggest you use the Docker Desktop WSL2 integration.

# Systemd in WSL2

You can use a hack such as [this one](https://hoverbear.org/blog/getting-the-most-out-of-wsl/#get-systemd-functional), but really, this isn't a good solution. *(Largely because Microsoft updates it a lot and things break often.)*

I suggest you investigate a Hyper-V, VMWare, or VirtualBox VM. Alternatively, if you have another disk, dual booting is quite reasonable if you give each OS a disk.