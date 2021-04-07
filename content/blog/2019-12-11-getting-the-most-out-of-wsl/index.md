+++
title = "Getting the most of WSL"
description = "Some tricks for getting more mileage from your Linux subsystem"
template = "blog/single.html"
[taxonomies]
tags = [
    "Tutorials"
]
[extra]
[extra.image]
path =  "cover.jpg"
photographer = "Matthieu Joannon; @matt_j on Unsplash"
+++

Not long ago, Microsoft started iterating more heavily on their long-existing "Windows Subsystem for Linux" feature. The feature has existed for some time, but recently has it become much more usable for everyday Linux development work.

In this post, we'll investigate some ways to get the most out of WSL. I won't present anything new here, just providing a single place for how I or someone else **could** get things set up.

<!-- more -->

> This guide was written on Windows 10 Pro, Insiders build 18985, targetting Ubuntu. Your mileage may vary on older/newer builds or different distros.

## Getting it set up

Getting WSL set up has a few steps, first you'll need to add some Windows optional Features.

```powershell
# In an administrator powershell
Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux"
Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" 
wsl --set-default-version 2
```

Next, head on over to the Windows Store and install ['Ubuntu'](https://www.microsoft.com/en-ca/p/ubuntu/9nblggh4msv6?activetab=pivot:overviewtab). Once it's downloaded you should launch it and do the first time setup. It'll ask you to put a username and password.

At the point, you have a WSL2 installation of Ubuntu. To verify:

```powershell
$ wsl -l -v
  NAME      STATE           VERSION
* Ubuntu    Running         2
```

To access Ubuntu type `wsl` from Powershell, or open the 'Ubuntu' app in your Start Menu.

## Updating Ubuntu

The Ubuntu version you should have is Ubuntu 18.04. (Check with `lsb_release -r`) In order to upgrade it to Ubuntu 19.04 

```bash
wsl sudo sed -i 's/Prompt=lts/Prompt=normal/g' /etc/update-manager/release-upgrades
wsl sudo do-release-upgrade
```

If the process asks you about "restart services during package upgrades without asking" you should pick **no**! If it asks you for a list of services to restart, just have it empty.

> Our Ubuntu isn't running `systemd` (yet) so we don't have to restart the services.

If the process asks you about lxd and the snap store, you can select **skip**. Since we're not running `lxd` and `snapd` (yet) we don't need it.

For any new configuration files (such as `sshd`) select **install the package maintainer's version**.

Then, let it 'restart', restart the WSL machine with `wsl --shutdown` from a Powershell.

Open up a Ubuntu shell and check `lsb_release -r` again. For me it says 19.04. This means I need to upgrade again to get to 19.10!

```bash
wsl sudo do-release-upgrade
```

Following the same procedure, `lsb_release -r` for me now shows 19.10.

## Better terminals

The ['Windows Terminal'](https://www.microsoft.com/en-ca/p/windows-terminal-preview/9n0dx20hk701?activetab=pivot:overviewtab) app provides a nicer terminal experience.


{{ figure(path="terminal-chooser.jpg", alt="Windows Terminal chooser", colocated=true) }}

You can also install [VS Code Insiders](https://code.visualstudio.com/insiders/) and the [Remote - WSL](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl) extension to get a full featured editor/explorer.

{{ figure(path="vscode-chooser.jpg", alt="VS Code chooser", colocated=true) }}

Occasionally VS Code, the extension, or something else will update and render it unable to connect. Opening a local VS Code window, closing it, then restarting the computer should fix it.

## Configuring WSL

Typically, you won't want your WSL instance to be able to consume all your resources. You may also want to disable things like swap.

Save a file to `%UserProfile%/.wslconfig` with contents like the following:

```ini
[wsl2]
memory=12GB
swap=0
```

To apply these changes, run `wsl --shutdown` and open up a new Ubuntu terminal.

## Passwordless `sudo`

Having to deal with passwords in a dev VM is kind of annoying. Let's turn that off in Ubuntu:

```bash
cat <<-'EOF' | sudo tee -a /etc/sudoers.d/sudo
%sudo         ALL = (ALL) NOPASSWD: ALL
EOF
```

## Set up SSH keys

If you've already rolled keys with Window's built-in `ssh-keygen` you should copy over your existing key.

In your Ubuntu shell (change your user if it's different between Windows and Linux):

```bash
mkdir -p ~/.ssh
cp -r /mnt/c/Users/$USER/.ssh/* ~/.ssh/
chmod -R o-rwx,g-rwx ~/.ssh/*
```

If you haven't already, roll some keys in Linux and copy them the other way:

```bash
mkdir -p /mnt/c/Users/$USER/.ssh/
cp -r ~/.ssh/* /mnt/c/Users/$USER/.ssh/
```

Unfortunately we can't easily link them since they're on different devices.

## Get `systemd` functional

At this stage of WSL2's development, we don't get a true `systemd` *yet*. That is, by default, you can't do things like `systemctl start sshd` or `systemctl start docker`.

Thankfully, a wonderful person in the Snapcraft project, [Daniel](https://forum.snapcraft.io/u/daniel/summary), got an [amazingly convienent hack working](https://forum.snapcraft.io/t/running-snaps-on-wsl2-insiders-only-for-now/13033)! While you may want to fully review the linked article, here's a quick and dirty breakdown.

In your Ubuntu shell:

> Ubuntu 20.20? Daemonize is moved according to [@ram0973](https://twitter.com/ram0973/status/1253647608670814217) found
> it on the `/usr/bin/daemonize` path.

```bash
sudo apt-get install -yqq daemonize dbus-user-session
cat <<-'EOF' | sudo tee -a /usr/sbin/start-systemd-namespace > /dev/null
#!/bin/bash

SYSTEMD_PID=$(ps -ef | grep '/lib/systemd/systemd --system-unit=basic.target$' | grep -v unshare | awk '{print $2}')
if [ -z "$SYSTEMD_PID" ] || [ "$SYSTEMD_PID" != "1" ]; then
    export PRE_NAMESPACE_PATH="$PATH"
    (set -o posix; set) | \
        grep -v "^BASH" | \
        grep -v "^DIRSTACK=" | \
        grep -v "^EUID=" | \
        grep -v "^GROUPS=" | \
        grep -v "^HOME=" | \
        grep -v "^HOSTNAME=" | \
        grep -v "^HOSTTYPE=" | \
        grep -v "^IFS='.*"$'\n'"'" | \
        grep -v "^LANG=" | \
        grep -v "^LOGNAME=" | \
        grep -v "^MACHTYPE=" | \
        grep -v "^NAME=" | \
        grep -v "^OPTERR=" | \
        grep -v "^OPTIND=" | \
        grep -v "^OSTYPE=" | \
        grep -v "^PIPESTATUS=" | \
        grep -v "^POSIXLY_CORRECT=" | \
        grep -v "^PPID=" | \
        grep -v "^PS1=" | \
        grep -v "^PS4=" | \
        grep -v "^SHELL=" | \
        grep -v "^SHELLOPTS=" | \
        grep -v "^SHLVL=" | \
        grep -v "^SYSTEMD_PID=" | \
        grep -v "^UID=" | \
        grep -v "^USER=" | \
        grep -v "^_=" | \
        cat - > "$HOME/.systemd-env"
    echo "PATH='$PATH'" >> "$HOME/.systemd-env"
    exec sudo /usr/sbin/enter-systemd-namespace "$BASH_EXECUTION_STRING"
fi
if [ -n "$PRE_NAMESPACE_PATH" ]; then
    export PATH="$PRE_NAMESPACE_PATH"
fi
EOF
sudo chmod +x /usr/sbin/start-systemd-namespace
cat <<-'EOF' | sudo tee -a /usr/sbin/enter-systemd-namespace > /dev/null
#!/bin/bash

if [ "$UID" != 0 ]; then
    echo "You need to run $0 through sudo"
    exit 1
fi

SYSTEMD_PID="$(ps -ef | grep '/lib/systemd/systemd --system-unit=basic.target$' | grep -v unshare | awk '{print $2}')"
if [ -z "$SYSTEMD_PID" ]; then
    /usr/sbin/daemonize /usr/bin/unshare --fork --pid --mount-proc /lib/systemd/systemd --system-unit=basic.target
    while [ -z "$SYSTEMD_PID" ]; do
        SYSTEMD_PID="$(ps -ef | grep '/lib/systemd/systemd --system-unit=basic.target$' | grep -v unshare | awk '{print $2}')"
    done
fi

if [ -n "$SYSTEMD_PID" ] && [ "$SYSTEMD_PID" != "1" ]; then
    if [ -n "$1" ] && [ "$1" != "bash --login" ] && [ "$1" != "/bin/bash --login" ]; then
        exec /usr/bin/nsenter -t "$SYSTEMD_PID" -a \
            /usr/bin/sudo -H -u "$SUDO_USER" \
            /bin/bash -c 'set -a; source "$HOME/.systemd-env"; set +a; exec bash -c '"$(printf "%q" "$@")"
    else
        exec /usr/bin/nsenter -t "$SYSTEMD_PID" -a \
            /bin/login -p -f "$SUDO_USER" \
            $(/bin/cat "$HOME/.systemd-env" | grep -v "^PATH=")
    fi
    echo "Existential crisis"
fi
EOF
sudo chmod +x /usr/sbin/enter-systemd-namespace
cat <<-'EOF' | sudo tee -a /etc/sudoers.d/wsl > /dev/null
Defaults        env_keep += WSLPATH
Defaults        env_keep += WSLENV
Defaults        env_keep += WSL_INTEROP
Defaults        env_keep += WSL_DISTRO_NAME
Defaults        env_keep += PRE_NAMESPACE_PATH
%sudo ALL=(ALL) NOPASSWD: /usr/sbin/enter-systemd-namespace
EOF
sudo sed -i 2a"# Start or enter a PID namespace in WSL2\nsource /usr/sbin/start-systemd-namespace\n" /etc/bash.bashrc
```

In Powershell, set some final knobs then restart WSL:

```powershell
cmd.exe /C setx WSLENV BASH_ENV/u
cmd.exe /C setx BASH_ENV /etc/bash.bashrc
wsl --shutdown
```

Finally, install `docker.io` with `apt` and have a try:

{{ figure(path="systemd.jpg", alt="Docker running in Sytemd", colocated=true) }}
