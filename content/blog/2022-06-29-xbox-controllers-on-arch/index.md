+++
title = "Xbox Controllers on Arch Linux"
description = "Some games are simply better on controller."
template =  "blog/single.html"

[taxonomies]
tags = [
    "Arch Linux",
]

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Jakub Sisulak"
source = "https://unsplash.com/photos/sKJPFpnHA2A"
+++

I fumbled a bit setting up my Xbox controller in Arch, but managed it and wanted to share.

Let's quickly cover how to use [`xone`][github.com/medusalix/xone] to set up a [Xbox Elite Wireless Controler Series 2][xbox.com/../elite-wireless/controler/series-2] connecting to [Arch Linux][archlinux.org] via a [Xbox Wireless Adapter for Windows 10][xbox.com/../wireless-adapter/windows]. Once we're done, it should 'just work' in [`steam`][archlinux.org/../steam], [`wine`][archlinux.org/../wine], [`lutris`][archlinux.org/../lutris], or your other games.

<!-- more -->

# Prerequisites

First, **Unplug the wireless adapter and controller.** This helps ensure when we do plug them in later, after installing the drivers, it'll work correctly.

You'll also want to make sure your GPU is properly working, with 3D OpenGL acceleration. You should refer to the Arch Linux wiki related to your GPU for this. (I use AMD GPUs so I just install `mesa` and `lib32-mesa`)

Since the Xbox Wireless Adapter uses WiFi at 2.4 GHz, you will also need a working WiFi stack on your machine. I used GNOME and the stock kernel, so Network Manager was simple to set up:

```bash
sudo pacman -S networkmanager
sudo systemctl enable --now NetworkManager
```

Any other networking management styles should work too.

If you haven't already, setup [`yay`][github.com/Jguer/yay] or another [AUR][aur.archlinux.org] helper, we'll need it later:

```bash
sudo pacman -S git base-devel
mkdir -p ~/git/Jguer
cd !$
git clone https://aur.archlinux.org/yay.git
cd yay
$EDITOR PKGBUILD
makepkg -si
```

If you haven't yet, enable the `multilib` repository in Arch. In `/etc/pacman.conf` uncomment these lines, then run `sudo pacman -Syu` to make sure things are solid:

```bash
[multilib]
Include = /etc/pacman.d/mirrorlist
```

If you haven't yet, you can install [`steam`][archlinux.org/../steam], [`wine`][archlinux.org/../wine] as well as [`lutris`][archlinux.org/../lutris]:

```bash
sudo pacman -S steam lutris wine
```

We **will cover** how to set up the controller inside Steam later. Lutris works out of the box.

Finally, you'll need to make sure your user is in the `input` group.

```bash
sudo gpasswd -a ana input
```

**Changing user groups in Linux requires you to relog or reboot**, so please do that.

# Xone

At the time of writing, [`xone`][github.com/medusalix/xone] 3.0 recently arrived in the [AUR][aur.archlinux.org] as [`xone-dkms`][aur.archlinux.org/../xone-dkms] and it works well.

```bash
yay -S xone-dkms
```

> **Don't be brash**, read the [`PKGBUILD`][wiki.archlinux.org/../PKGBUILD]s which `yay` shows you, ensure you are comfortable with them. **Do this every time, no matter what.**

During the build, it will pull in the [`xone-dongle-firmware`][aur.archlinux.com/../xone-dongle-firmware] which contains the required binary blobs.

At this point, we could probably plug in the controller and get it to show up in Steam or Wine! You might even be able to pair the controller! But could we actually use it in a game? **No!** When I tried, pressing 'A' on the controller would click, and all sorts of weird things were happening.

It turns out things work a lot better with [`xpad`][github.com/paroj/xpad] installed too! The standard install of `xpad` contains drivers though, which `xone` already provides. The `xone` maintainer provides [`xpad-noone`][github.com/medusalix/xpad-noone], a fork without the conflicting drivers removed, which is also in the AUR as [`xpad-noone-dkms`][aur.archlinux.org/../xpad-noone-dkms]:

```bash
yay -S xpad-noone-dkms
```

> **Did you notice that in the `PKGBUILD`?** The `xpad-noone-dkms` AUR package takes it's source from a fork of the medusalix's repo. You should [compare the diff][github.com/medusalix/xpad-noone/compare] and **ensure it is not maliciously altered**. (It was harmless at the time of writing this.) You may prefer it install it directly from the repository.

# Preliminary Wired testing

At this point, just to be extra thorough, reboot! When you're back to your desktop, plug in the controller with a wire, let's make sure that works first.

Once plugged in, your controller should rumble softly and light up. If you tag along with `sudo dmesg --follow`:

```bash
[ 6925.448346] usb 5-1: new full-speed USB device number 6 using xhci_hcd
[ 6925.611684] usb 5-1: New USB device found, idVendor=045e, idProduct=0b00, bcdDevice= 4.08
[ 6925.611690] usb 5-1: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[ 6925.611692] usb 5-1: Product: Controller
[ 6925.611694] usb 5-1: Manufacturer: Microsoft
..
[ 6926.197830] input: Microsoft X-Box One pad as /devices/pci0000:00/0000:00:08.1/0000:0e:00.3/usb5/5-1/5-1:1.0/gip0/gip0.0/input/input45
..
[ 6927.391184] input: Microsoft X-Box 360 pad 0 as /devices/virtual/input/input48
[ 6927.492458] input: Microsoft X-Box 360 pad 1 as /devices/virtual/input/input49
```

That looks good! At the end there are two 'devices', that's ok. Now we can check the `evdev` API for a device postfixed with `-event-joystick`. We can `cat` it then push the 'A' button on your controller:

```
[ana@architect ~]$ cat /dev/input/by-id/usb-Microsoft_Controller_*-event-joystick
2�b_)02�b_)����2�b_)2�b?�02�b?�^C
```

The [Unicode 'tofu'][en.wikipedia.org/../Specials_(Unicode_block)] is a good sign. Ctrl+C out.

# Steam Specific Settings

Pop open `steam` and navigate the menus: 'Steam' -> 'Settings' -> 'Controller' -> 'General Controller Settings'.

There, tick on 'Xbox Configuration Support'. You should see Xbox controllers showing up now.

{{ figure(path="controller-settings.jpg", alt="Steam Controller", colocated=true) }}

# Wireless Pairing

Unplug your controller from the wire and plug in the Xbox Wireless Adapter.

Checking `sudo dmesg --follow`:

```
[ 7708.489792] usb 3-6.3: new high-speed USB device number 8 using xhci_hcd
[ 7708.586329] usb 3-6.3: New USB device found, idVendor=045e, idProduct=02fe, bcdDevice= 1.00
[ 7708.586334] usb 3-6.3: New USB device strings: Mfr=1, Product=2, SerialNumber=3
[ 7708.586336] usb 3-6.3: Product: XBOX ACC
[ 7708.586337] usb 3-6.3: Manufacturer: Microsoft Inc.
..
[ 7708.765135] xone-dongle 3-6.3:1.0: xone_mt76_send_firmware: build=201703281033____
[ 7708.908197] xone-dongle 3-6.3:1.0: xone_mt76_init_radio: id=0x7613
[ 7708.937447] xone-dongle 3-6.3:1.0: xone_mt76_init_address: address=6c:5d:3a:01:cb:ce
..
[ 7709.072740] xone-dongle 3-6.3:1.0: xone_dongle_toggle_pairing: enabled=1
```

At this point you should be able to follow the [Xbox Adapter Pairing guide][support.xbox.com/../connect-xbox-wireless-controller-to-pc].

**TL;DR:** Push adapter button so the white light on it flashes (no flash? See [troubleshooting](#troubleshooting)), push Xbox Guide button to turn on controller, push pair button on controller so the guide button flashes, repeat until it finally works and the controller light stays lit.

In `sudo dmesg --follow` it'll look like so:

```
..
[ 8114.834465] xone-dongle 3-6.1:1.0: xone_dongle_pair_client: address=7e:ed:82:51:03:4e
[ 8114.834847] xone-dongle 3-6.1:1.0: xone_dongle_toggle_pairing: enabled=0
[ 8115.103078] xone-gip gip0: gip_create_adapter: registered
[ 8115.103227] xone-dongle 3-6.1:1.0: xone_dongle_add_client: wcid=1, address=7e:ed:82:51:03:4e
[ 8115.615568] xone-gip gip0.0: gip_init_client: initialized
[ 8115.615574] xone-gip gip0.0: gip_handle_pkt_announce: address=7e:ed:82:51:03:4e, vendor=0x045e, product=0x0b00
[ 8115.615578] xone-gip gip0.0: gip_handle_pkt_announce: firmware=4.8.1908.0, hardware=1541.1.1.1
..
[ 8115.688157] xone-gip gip0.0: gip_parse_classes: class=Windows.Xbox.Input.Gamepad
[ 8115.688159] xone-gip gip0.0: gip_parse_classes: class=Microsoft.Xbox.Input.ProgrammableGamepad
..
[ 8115.688380] input: Microsoft X-Box One pad as /devices/pci0000:00/0000:00:01.2/0000:02:00.0/0000:03:08.0/0000:07:00.3/usb3/3-6/3-6.1/3-6.1:1.0/gip0/gip0.0/input/input55
[ 8115.688508] xone-gip-gamepad gip0.0: gip_add_client: added
[ 8115.704286] xone-gip gip0.1: gip_init_client: initialized
..
[ 8115.752704] input: Microsoft X-Box One chatpad as /devices/pci0000:00/0000:00:01.2/0000:02:00.0/0000:03:08.0/0000:07:00.3/usb3/3-6/3-6.1/3-6.1:1.0/gip0/gip0.1/input/input56
[ 8115.752961] input: Microsoft X-Box One chatpad as /devices/pci0000:00/0000:00:01.2/0000:02:00.0/0000:03:08.0/0000:07:00.3/usb3/3-6/3-6.1/3-6.1:1.0/gip0/gip0.1/0003:045E:0B02.0010/input/input57
[ 8115.753198] hid-generic 0003:045E:0B02.0010: input,hidraw10: USB HID v1.01 Keyboard [Microsoft X-Box One chatpad] on gip0.1/input1
[ 8115.753219] xone-gip-chatpad gip0.1: gip_add_client: added
[ 8116.412501] input: Microsoft X-Box 360 pad 0 as /devices/virtual/input/input58
[ 8116.678046] input: Microsoft X-Box 360 pad 1 as /devices/virtual/input/input59
```

At this point, we're ready to test everything!

# Final testing

To test in `wine`, I ran `wine control joy.cpl`, and reviewed the listed 'Connected (xinput device)' box for 'Controller (Xbox One for Windows)'. In the 'Test Joystick' tab you can do inputs into the controller and see them reflected in the UI. That means we're good to go!

{{ figure(path="wine-settings.jpg", alt="Steam Controller", colocated=true) }}

With that working, I was able to launch some of my favorite controller games like [Ikenfell][humblegames.com/games/ikenfell] and [No Man's Sky][nomanssky.com].

{{ figure(path="nms.jpg", alt="No Man's Sky", colocated=true) }}

# Troubleshooting

> Help Ana, the adapter won't flash a pairing light!

I had this happen to! Unplug it, uninstall the `xone` related stuff above, then reinstall cleanly (that is -- if asked, 'cleanbuild'), **only then** plug it in! That step above was important! 😉

> Ana you missed a step!

Please contact me or make a [PR to this article][github.com/Hoverbear/hoverbear.org]! I want this to be complete.

> Something else.

**Please do not email me asking support questions about getting Steam, Lutris, or any game working on your machine.**

**Please do not email me about any devices other than the ['Xbox Elite Wireless Controler Series 2'][xbox.com/../elite-wireless/controler/series-2] and ['Xbox Wireless Adapter for Windows 10'][xbox.com/../wireless-adapter/windows].**

**Please do not email me about using something other than `xone` on Arch Linux x86_64.**

**Please do not email me if you have problems with the AUR packages.**

[github.com/medusalix/xone]: https://github.com/medusalix/xone
[xbox.com/../elite-wireless/controler/series-2]: https://www.xbox.com/en-CA/accessories/controllers/elite-wireless-controller-series-2
[xbox.com/../wireless-adapter/windows]: https://www.xbox.com/en-CA/accessories/adapters/wireless-adapter-windows
[archlinux.org]: https://archlinux.org/
[steampowered.com]: https://store.steampowered.com/
[archlinux.org/../steam]: https://archlinux.org/packages/multilib/x86_64/steam/
[archlinux.org/../lutris]: https://archlinux.org/packages/community/any/lutris/
[lutris.net]: https://lutris.net/
[github.com/Jguer/yay]: https://github.com/Jguer/yay
[aur.archlinux.org]: https://aur.archlinux.org/
[aur.archlinux.org/../xone-dkms]: https://aur.archlinux.org/packages/xone-dkms
[github.com/medusalix/xone]: https://github.com/medusalix/xone
[aur.archlinux.com/../xone-dongle-firmware]: https://aur.archlinux.org/packages/xone-dongle-firmware
[archlinux.org/../wine]: https://archlinux.org/packages/multilib/x86_64/wine/
[aur.archlinux.org/../xpad-noone-dkms]: https://aur.archlinux.org/packages/xpad-noone-dkms
[github.com/paroj/xpad]: https://github.com/paroj/xpad
[github.com/medusalix/xpad-noone]: https://github.com/medusalix/xpad-noone
[github.com/medusalix/xpad-noone/compare]: https://github.com/medusalix/xpad-noone/compare/master...LINCKODE:xpad-noone:v1.0
[en.wikipedia.org/../Specials_(Unicode_block)]: https://en.wikipedia.org/wiki/Specials_(Unicode_block)
[support.xbox.com/../connect-xbox-wireless-controller-to-pc]: https://support.xbox.com/en-US/help/hardware-network/controller/connect-xbox-wireless-controller-to-pc
[dreamscapergame.com]: https://dreamscapergame.com/
[humblegames.com/games/ikenfell/]: https://www.humblegames.com/games/ikenfell/
[nomanssky.com]: https://www.nomanssky.com/
[github.com/Hoverbear/hoverbear.org]: https://github.com/Hoverbear/hoverbear.org