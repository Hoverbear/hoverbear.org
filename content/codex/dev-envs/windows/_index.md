+++
title = "Windows"
description = "A fickle, proprietary fragile, expensive monstrosity."
sort_by = "weight"
template =  "blog/list.html"

[extra]
in_menu = true

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Roseanna Smith"
source = "https://unsplash.com/photos/-qzLjuJEmsE"
+++

# Use PowerShell

To get to a PowerShell from a command prompt:

```bat
powershell
```

You can also hit the Windows (⊞) key and type in "PowerShell" to find a PowerShell Prompt.

I prefer to configure my IDEs to also use PowerShell. In Visual Studio Code (VSCode):

```js
// Settings.json
{
    // ...
    "terminal.integrated.shell.windows": "powershell.exe"
}
```

# Use a Package Manager

There are several options such as [`scoop`](https://scoop.sh/) for Windows.

```powershell
Set-ExecutionPolicy RemoteSigned -scope CurrentUser
Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
scoop install sudo
sudo echo "Bloop"
```