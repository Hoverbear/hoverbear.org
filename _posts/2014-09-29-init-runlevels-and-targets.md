---
layout: post
title: "Init - Runlevels and Targets"

tags:
 - Init
 - Tutorials
 - CSC499
---


In this post, we'll look at how runlevels work in two major init systems, systemd and OpenRC. If you're interested in trying out systemd, I'd suggest using an [Arch Linux Live ISO](https://www.archlinux.org/download/). For those interested in trying OpenRC, check out [Funtoo](http://www.funtoo.org/Funtoo_Linux_Installation). Both of these will work great in your favorite virtualization solution.

# OpenRC

OpenRC uses runlevels in very much the same way as sysvinit (or BSD init). At any given time the system is in one of the defined runlevels, there are three internal runlevels and four user defined runlevels.

**Internal Runlevels:**

* `sysinit`: Initialize the system.
* `shutdown`: Power off the system.
* `reboot`: Rebooting the system.

**User Runlevels:**

* `boot`: Starts all system-necessary services for other runlevels.
`default`: Used for day-to-day-operations
* `nonetwork`: Used when no network connectivity is required.
* `single`: Single-user mode.

A system transitions between runlevels like so:

```bash
sysinit -> boot -> default -> shutdown
```

The services controlled by a particular runlevel are controlled by `/etc/inittab` and via the `rc-update` command.

On a modern [Funtoo LXC Container](http://www.funtoo.org/Funtoo_Hosting), your runlevels  might look like this:

```bash
± # rc-update -v
             bootmisc | boot
         busybox-ntpd |
     busybox-watchdog |
          consolefont |
                 dbus |
                devfs |                       sysinit
               dhcpcd |
                dmesg |                       sysinit
                 fsck | boot
           git-daemon |
                  gpm |
             hostname | boot
              hwclock | boot
             iptables |      default
              keymaps | boot
            killprocs |              shutdown
    kmod-static-nodes |                       sysinit
                local |      default
           localmount | boot
              modules | boot
             mount-ro |              shutdown
                 mtab | boot
               murmur |
           netif.eth0 |      default
             netif.lo |                       sysinit
           netif.tmpl |
             netmount |      default
                nginx |      default
              numlock |
              openvpn |      default
              pciparm |
              postfix |
               procfs | boot
            pydoc-2.7 |
            pydoc-3.3 |
            pydoc-3.4 |
                redis |
                 root | boot
               rsyncd |
            savecache |              shutdown
                 sshd |      default
                 swap | boot
            swapfiles | boot
              swclock |
               sysctl | boot
                sysfs |                       sysinit
         termencoding | boot
         tmpfiles.dev |                       sysinit
       tmpfiles.setup | boot
                 udev |                       sysinit
           udev-mount |                       sysinit
       udev-postmount | boot
              urandom | boot
```

Services can be added to runlevels with:

```bash
rc-update add <service> <runlevel>
```

Or removed with:

```bash
rc-update del <service> <runlevel>
```

Changing between runlevels is done via the `rc <runlevel>` command, but most users will never need to do this as runlevels are (mostly) managed by the system.

In the case where a user does want to change runlevels in this way, it is often such that they are utilizing [Stacked Runlevels](http://www.funtoo.org/Stacked_Runlevels).

For example, if a user wanted to differentiate which services were running on their laptop when it was powered or on battery, they could create two separate runlevels stacked atop `default`. While plugged in, the laptop could be running test databases or any number of services, but after changing runlevels these services could be disabled to save on battery.

#### Benefits

* **Simple:** There are (normally) only 7 runlevels, and for most of it's time the system remains on the `default` runlevel.
* **Established:**  `init` and `sysvinit` have been using runlevels for ages.
* **Sufficient:** Runlevels have been shown to provide sufficient functionality for most applications.

#### Downfalls

* **Inflexible:** While there are ways to create 'Stacked Runlevels', the system is not very capable of more exotic requirements.
* **Aging:** Modern systems, especially desktops and laptops, frequently change their hardware (inserting a USB stick), or network settings (Changing between WiFi networks), steps have been taken by system designers to handle these stumbling blocks, but it's not longer always sufficient to scan once for hardware, for example.

# systemd

`systemd` uses targets instead of runlevels. Each target has a unique name, and multiple targets can be active at one time. Since most distributions using systemd have migrated from a runlevel based init system, there are targets which roughly correspond to the runlevels used by OpenRC, `init`, and `sysvinit`.

* `poweroff`: Halt the system.
* `rescue`: Single user mode.
* `multi-user`: Multi-user, non-graphical. User-defined/Site-specific runlevels.
* `graphical`: Multi-user, graphical. Usually multi-user + graphical login.
* `reboot`: Reboot
* `emergency`: Emergency Shell

It's important to understand that these are not necessarily the only active targets. In the case of the `graphical` target, a display manager service like `kdm` might be started, this target would also activate the `multi-user` target.

The `multi-user` target might also activate a service like `dbus`, and another target named `basic`. This is interesting because it allows us to cleanly compose and extend the system to suit our needs.

A `.target` file resides in `/usr/lib/systemd/system` or `/usr/lib/systemd/system/` and looks like this:

```
[Unit]
Description=Graphical Interface
Documentation=man:systemd.special(7)
Requires=multi-user.target
After=multi-user.target
Conflicts=rescue.target
Wants=display-manager.service
AllowIsolate=yes
```

This file would be accompanied by a `<target>.wants` directory containing the services it should enable.

Targets can be controlled very similar to systemd's `.service` unit files, you just need to add `.target` at the end.

```bash
systemctl status graphical.target
± % systemctl status graphical.target
graphical.target - Graphical Interface
Loaded: loaded (/lib/systemd/system/graphical.target; enabled)
Active: active since Thu 2014-09-25 21:21:26 PDT; 4 days ago
Docs: man:systemd.special(7)

 Sep 25 21:21:26 aluminum systemd[1]: Starting Graphical Interface.
 Sep 25 21:21:26 aluminum systemd[1]: Reached target Graphical Interface.
```

The `.target` based approach allows for various services to be grouped in a logical manner. For example, is is the state of targets on a modern Fedora Desktop:

```bash
± % systemctl list-units --type=target --all
UNIT                   LOAD      ACTIVE   SUB    DESCRIPTION
basic.target           loaded    active   active Basic System
bluetooth.target       loaded    active   active Bluetooth
cryptsetup-pre.target  loaded    inactive dead   Encrypted Volumes (Pre)
cryptsetup.target      loaded    active   active Encrypted Volumes
emergency.target       loaded    inactive dead   Emergency Mode
final.target           loaded    inactive dead   Final Step
getty.target           loaded    active   active Login Prompts
graphical.target       loaded    active   active Graphical Interface
local-fs-pre.target    loaded    active   active Local File Systems (Pre)
local-fs.target        loaded    active   active Local File Systems
multi-user.target      loaded    active   active Multi-User System
network-online.target  loaded    inactive dead   Network is Online
network.target         loaded    active   active Network
nfs.target             loaded    active   active Network File System Server
nss-user-lookup.target loaded    inactive dead   User and Group Name Lookups
paths.target           loaded    active   active Paths
remote-fs-pre.target   loaded    inactive dead   Remote File Systems (Pre)
remote-fs.target       loaded    active   active Remote File Systems
rescue.target          loaded    inactive dead   Rescue Mode
shutdown.target        loaded    inactive dead   Shutdown
sleep.target           loaded    inactive dead   Sleep
slices.target          loaded    active   active Slices
sockets.target         loaded    active   active Sockets
sound.target           loaded    active   active Sound Card
suspend.target         loaded    active   active Suspend
swap.target            loaded    active   active Swap
sysinit.target         loaded    active   active System Initialization
syslog.target          not-found inactive dead   syslog.target
time-sync.target       loaded    inactive dead   System Time Synchronized
timers.target          loaded    active   active Timers
umount.target          loaded    inactive dead   Unmount All Filesystems

LOAD   = Reflects whether the unit definition was properly loaded.
ACTIVE = The high-level unit activation state, i.e. generalization of SUB.
SUB    = The low-level unit activation state, values depend on unit type.

31 loaded units listed.
To show all installed unit files use 'systemctl list-unit-files'.
```

#### Benefits

* **Composition**: Allows for services to be composed together in logical, user-defined groups easily.
* **Configuration**: It's simple to add custom targets.
* **Less Restrictive**: Since multiple targets can be active at a given time, the system's behavior can be more finely defined.

#### Downfalls

* **Complexity**: A sufficiently sophisticated installation could be composed of dozens of targets, and can require a deeper understanding of the system.

# Further Reading
* [Rethinking PID 1](http://0pointer.de/blog/projects/systemd.html)
* [Red Hat: Working with systemd Targets](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/sect-Managing_Services_with_systemd-Targets.html)
* [Systemd Target](http://www.freedesktop.org/software/systemd/man/systemd.target.html)
* [Systemd status update 1](http://0pointer.de/blog/projects/systemd-update.html)
* [Systemd status update 2](http://0pointer.de/blog/projects/systemd-update-2.html)
* [Systemd status update 3](http://0pointer.de/blog/projects/systemd-update-3.html)
* [Comparison of init Systems](http://wiki.gentoo.org/wiki/Comparison_of_init_systems)
* [s6 why?](http://skarnet.org/software/s6/why.html)
* [Initscripts (Gentoo Handbook)](https://www.gentoo.org/doc/en/handbook/handbook-x86.xml?part=2&chap=4#doc_chap5)
* [Stacked Rulevels (Funtoo Wiki)](http://www.funtoo.org/Stacked_Runlevels)
