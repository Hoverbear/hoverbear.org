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