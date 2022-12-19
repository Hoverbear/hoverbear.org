+++
title = "Declarative GNOME configuration with NixOS"
description = "Using Home Manager to declaratively set key desktop environment knobs."
template =  "blog/single.html"

[taxonomies]
tags = [
    "Nix",
]

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Pierre Bamin"
source = "https://unsplash.com/photos/HKnaN1kTETk"
+++

I *adore* tinkering with my machine, trying new tools, extensions, themes, and ideas. When I was younger, it was simply a way to learn. Now, it's a way for me to refine my workspace and bring myself small joys.

While tinkering can be fun, it can be a chore to set up a new machine, keep configurations up to date between machines, or even just remember to keep up to date backups. We've previously explored how to create [**Configurable Nix packages**](/blog/configurable-nix-packages/), which solves the problem for things like `neovim`, but what about when a package isn't practically configurable?

What about when we want to configure a whole desktop environment? While [NixOS](https://nixos.org/) offers configuration settings like `services.gnome.gnome-keyring.enable` for systemwide features, there's a void of knobs when you want to set things like user-specific GNOME 'Favorite Apps' or extensions.

Let's explore a useful addition to your NixOS configuration: [Home Manager](https://nix-community.github.io/home-manager/) and its [`dconf`](https://wiki.gnome.org/Projects/dconf) module.

<!-- more -->

> This article uses [Nix flakes](https://nixos.wiki/wiki/Flakes) which is an experimental feature. You may need to set this in your configuration:
>
> ```nix
> nix.settings.experimental-features = [ "flakes" "nix-command" ];
> ```

# Getting Home Manager set up

Home manager is a tool from the Nix ecosystem that helps you take the declarative ideals of Nix/NixOS and apply them to your user's home directory (`$HOME`). It plugs in (as a [NixOS module](https://nixos.wiki/wiki/NixOS_modules)) to an existing NixOS configuration, or can be installed on different Linux as a user service.

In order to make some parts of your configuration declarative, Home Manager might take control of certain file paths, or set various options in things like `dconf`.

Because of its job, Home Manager can make updating your configuration **feel** more error-prone, but don't fear: Use a VCS like [`git`](https://git-scm.com/) to store your configuration. If your Home Manager setup breaks or acts strange for any reason, check the service status via `systemctl status home-manager-$USER` and `journalctl -u home-manager-$USER.service`. When in doubt, roll back your configuration and delete any files the errors are complaining about.

> In our example, the user is named `ana`, and the machine is named `gizmo`.

In your Nix flake, add the input for Home Manager and ensure it follows the `nixpkgs` you're using:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # ...
  };
  # ...
}
```

If you don't already have GNOME configured, you can do that via a `nixosModule` like so:

```nix
# flake.nix
{
  # ...
  outputs = { self, nixpkgs, home-manager }:
    let 
      # ...
    in {
      # ...
      nixosModules = {
        # ...
        gnome = { pkgs, ... }: {
          config = {
            services.xserver.enable = true;
            services.xserver.displayManager.gdm.enable = true;
            services.xserver.desktopManager.gnome.enable = true;
            environment.gnome.excludePackages = (with pkgs; [
              gnome-photos
              gnome-tour
            ]) ++ (with pkgs.gnome; [
              cheese # webcam tool
              gnome-music
              gedit # text editor
              epiphany # web browser
              geary # email reader
              gnome-characters
              tali # poker game
              iagno # go game
              hitori # sudoku game
              atomix # puzzle game
              yelp # Help view
              gnome-contacts
              gnome-initial-setup
            ]);
            programs.dconf.enable = true;
            environment.systemPackages = with pkgs; [
              gnome.gnome-tweaks
            ]
          };
        };
      };
    };
}

```

Next, add a `nixosModule` that enables `home-manager`:

```nix
# flake.nix
{
  # ...
  outputs = { self, nixpkgs, home-manager }:
    let 
      # ...
    in {
      # ...
      nixosModules = {
        # ...
        declarativeHome = { ... }: {
          config = {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
          };
        };
      };
    };
}
```

I create a `nixosModule` for each of my users (you may have another way, feel free to do that):

```nix
# flake.nix
{
  # ...
  outputs = { self, nixpkgs, home-manager }:
    let 
      # ...
    in {
      # ...
      nixosModules = {
        # ...
        users-ana = ./users/ana;
      };
    };
}
```

You can enable Home Manager for your user like so:

```nix
# users/ana/default.nix
{ ... }:

{
  config = {
    home-manager.users.ana = ./home.nix;
    users.users.ana = {
      # ...
    };
  };
}
```

Now create the `home.nix` referenced above:

```nix
# users/ana/home.nix
{ ... }:

{
  home.username = "ana";
  home.homeDirectory = "/home/ana";
  # ...
  programs.home-manager.enable = true;
  home.stateVersion = "22.05";
}
```

Before enabling, ensure your `nixosConfiguration` has these modules, as well as `home-manager.nixosModules.home-manager`:

```nix
# flake.nix
{
  # ...
  outputs = { self, nixpkgs, home-manager }:
    let 
      # ...
    in {
      # ...
      nixosConfigurations = {
        gizmo = {
          system = "aarch64-linux";
          modules = with self.nixosModules; [
            ({ config = { nix.registry.nixpkgs.flake = nixpkgs; }; })
            # ...
            home-manager.nixosModules.home-manager
            gnome
            declarativeHome
            users-ana
          ];
        };
        # ...
      }
    };
}
```

With that, you should be able to switch into the new configuration:

```bash
nixos-rebuild switch --flake .#gizmo
```

Validate it worked by reviewing the output:

```bash
$ systemctl status home-manager-ana.service 
● home-manager-ana.service - Home Manager environment for ana
     Loaded: loaded (/etc/systemd/system/home-manager-ana.service; enabled; preset: enabled)
     Active: active (exited) since Mon 2022-09-26 22:15:32 PDT; 2s ago
    Process: 54958 ExecStart=/nix/store/nbhk58wgzvm2w8npi18qzjnn0xjcs3aw-hm-setup-env /nix/store/ig2vhy0pa4rvlkkdc511vyb6plp89x5a-home-manager-generation (code=exited, status=0/SU>
   Main PID: 54958 (code=exited, status=0/SUCCESS)
         IP: 0B in, 0B out
        CPU: 377ms
```

If you see errors, dig deeper via ` journalctl -u home-manager-ana.service`.



# Declaratively configuring GNOME

There are a lot of knobs to set in GNOME.

GNOME breaks down into having GTK3/4 (which has UI, icon, and cursor themes), as well as an group of fairly tightly integrated componenets which are primarily configured by `dconf`. Most folks configure these via `gnome-settings` or the settings panels of the relevant applications.

If you're curious and wanted to watch how/if various `dconf` settings get changed when doing things, you can 'watch' while you click around an application:

```bash
$ dconf watch /
/org/gnome/control-center/last-panel
  'network'

/system/proxy/mode
  'none'

/org/gnome/control-center/last-panel
  'background'

/org/gnome/desktop/interface/color-scheme
  'default'

/org/gnome/desktop/interface/color-scheme
  'prefer-dark'
```

If it's too noisy, you can limit what you see by changing the `/` to a selector, eg `/org/gnome/desktop/`.

Home Manager offers a `dconf` module, which we can use to declaratively set these values.

## GTK3/GTK4 cursor, icon, and window themes

To set the GTK icon theme, first search for a theme. [this search](https://search.nixos.org/packages?channel=unstable&from=0&size=200&sort=relevance&type=packages&query=-gtk-theme) or [this one](https://search.nixos.org/packages?channel=unstable&from=0&size=200&sort=relevance&type=packages&query=-theme) can help you find already packaged themes. You can click the "Source" button on any of those packages to see the expression used to package it, just in case you end up needing to make your own.

Here are the relevant settings, with some examples of what I've found that I like:

```nix
# users/ana/home.nix
{ pkgs, ... }:

{
  # ...
  gtk = {
    enable = true;

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    theme = {
      name = "palenight";
      package = pkgs.palenight-theme;
    };

    cursorTheme = {
      name = "Numix-Cursor";
      package = pkgs.numix-cursor-theme;
    };

    gtk3.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };

    gtk4.extraConfig = {
      Settings = ''
        gtk-application-prefer-dark-theme=1
      '';
    };
  };

  home.sessionVariables.GTK_THEME = "palenight";
  # ...
}
```

> Want to set the **GNOME Shell theme?** We do this [below](#gnome-extensions) after discussing `dconf` a bit more.

Finding the `name` field for a given package can be a bit inconsistent. 😔

Most of the time, you can guess it, or copy it from what shows up when you check with `gnome-tweaks`. Usually, you can find the package repository via the "Homepage" link on the searches listed above, or in the expression via the `meta.homepage` ([example](https://github.com/NixOS/nixpkgs/blob/62228ccc672ed000f35b1e5c82e4183e46767e52/pkgs/data/themes/gtk-theme-framework/default.nix#L32)) or `src` fields ([example](https://github.com/NixOS/nixpkgs/blob/62228ccc672ed000f35b1e5c82e4183e46767e52/pkgs/data/themes/gtk-theme-framework/default.nix#L7-L9)). From there you can usually find some listing of the theme name ([example](https://github.com/jnsh/arc-theme/blob/b9b98cb394f8acf0a09f3601e3294d406b8e40a5/meson.build#L13-L18)).

**To use a theme not already packaged**, you'll neeed to take a [good starting point](https://github.com/NixOS/nixpkgs/blob/62228ccc672ed000f35b1e5c82e4183e46767e52/pkgs/data/themes/arc/default.nix), edit it, then add your custom package to your flake:

```nix
# flake.nix
{
  # ...
  outputs = { self, nixpkgs, home-manager }:
    let 
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      # ...
    in {
      # ...
      overlays.default = final: prev: {
        my-artistanal-theme = final.callPackage ./packages/my-artisanal-theme { };
        # ...
      };

      packages = forAllSystems
        (system:
          let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [ self.overlays.default ];
              # ...
            };
          in
          {
            inherit (pkgs) my-artisanal-theme;
    };
}
```

Once done, you should be able to use it by setting, for example, `gtk.theme.package = pkgs.my-artisanal-theme`.

## Setting GNOME options

As mentioned [above](#declaratively-configuring-gnome), most GNOME settings exist in `dconf`. Run `dconf watch /` and set whatever option you're looking to declaratively persist, and observe the output:

Here's what I see when I run `gnome-settings` and visit the 'Appearance' pane, then in 'Style' click between 'Light' and 'Dark'.

```bash
$ dconf watch /
# ...

/org/gnome/desktop/interface/color-scheme
  'default'

/org/gnome/desktop/interface/color-scheme
  'prefer-dark'
```

Let's try setting those from the command line an observing the `gnome-settings` window change:

```bash
dconf write /org/gnome/desktop/interface/color-scheme "'default'"
# Observe `gnome-settings` being light
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
# Observe `gnome-settings` being dark
```

Using this information, we can add the following to the user configuration:

```nix
# users/ana/home.nix
{ pkgs, ... }:

{
  # ...
  # Use `dconf watch /` to track stateful changes you are doing, then set them here.
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };
}
```

After a bit of tweaking, you might end up with something like this:

```nix
# users/ana/home.nix
{ pkgs, ... }:

{
  # ...
  dconf.settings = {
    # ...
    "org/gnome/shell" = {
      favorite-apps = [
        "firefox.desktop"
        "code.desktop"
        "org.gnome.Terminal.desktop"
        "spotify.desktop"
        "virt-manager.desktop"
        "org.gnome.Nautilus.desktop"
      ];
    };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      enable-hot-corners = false;
    };
    "org/gnome/desktop/wm/preferences" = {
      workspace-names = [ "Main" ];
    };
    "org/gnome/desktop/background" = {
      picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-l.png";
      picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-d.png";
    };
    "org/gnome/desktop/screensaver" = {
      picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-d.png";
      primary-color = "#3465a4";
      secondary-color = "#000000";
    };
  };
}
```

## GNOME Extensions

Once user extensions are enabled, extensions can be added to the `home.packages` set then enabled in `dconf.settings."org/gnome/shell".enabled-extensions`. After, they can be configured just as any other GNOME option as described [just above](#setting-gnome-options).

```nix
# users/ana/home.nix
{ pkgs, ... }:

{
  # ...
  dconf.settings = {
    # ...
    "org/gnome/shell" = {
      disable-user-extensions = false;

      # `gnome-extensions list` for a list
      enabled-extensions = [
        "user-theme@gnome-shell-extensions.gcampax.github.com"
        "trayIconsReloaded@selfmade.pl"
        "Vitals@CoreCoding.com"
        "dash-to-panel@jderose9.github.com"
        "sound-output-device-chooser@kgshank.net"
        "space-bar@luchrioh"
      ];
    };
  };

  home.packages = with pkgs; [
    # ...
    gnomeExtensions.user-themes
    gnomeExtensions.tray-icons-reloaded
    gnomeExtensions.vitals
    gnomeExtensions.dash-to-panel
    gnomeExtensions.sound-output-device-chooser
    gnomeExtensions.space-bar
  ];
}
```

A GNOME Shell theme can be picked like this:

```nix
# users/ana/home.nix
{ pkgs, ... }:

{
  # ...
  dconf.settings = {
    # ...
    "org/gnome/shell" = {
      disable-user-extensions = false;

      enabled-extensions = [
        "user-theme@gnome-shell-extensions.gcampax.github.com"
      ];
      
      "org/gnome/shell/extensions/user-theme" = {
        name = "palenight";
      };
    };
  };

  home.packages = with pkgs; [
    # ...
    gnomeExtensions.user-themes
    palenight-theme
  ];
}
    
```

# Troubleshooting

> I made a bunch of changes then ran `nixos-rebuild switch`, but some things didn't change?

Log out and log back in. I found some things just didn't set themselves until you did!

> I accidently altered GNOME settings which I'd set via Home Manager, and they aren't changing back on a `nixos-rebuild switch`?

It is possible to change `dconf` values once set via Home Manager, if this happens and `nixos-rebuild switch` isn't causing a change, **you may need to restart the `home-manager` service** with `systemctl restart home-manager-$USER`. If that fails, make a change (eg. `touch`) your user home configuration first.

> Some changes I made are not reflecting when I `nixos-rebuild switch`?

Check `systemctl status home-manager-$USER` and ensure the service started sucessfully, if not, dig in with `journalctl -u home-manager-$USER` and make sure to carefully read the error.

> The setting I want isn't tracked by Home Manager or `dconf`?

It might be complicated. You can try seeing if the program creates an entry in your XDG directories, such as `~/.config` or `~/.cache`. If so, you can often provision content into the file with the [`home.file`](https://rycee.gitlab.io/home-manager/options.html#opt-home.file) option. Please note this will make the file unwritable, which may impact some programs.

# Conclusion

Once various all of your preferred settings are persisted, it becomes easy to share key settings and extensions between multiple machines, or even architectures. By taking a little bit more time when configuring our system, we can avoid having to do it again.

Using these strategies I was able to have 3 different machines (an x86_64 desktop workstation, an x86_64 laptop, and a headed aarch64 server) with the same settings, and keep them all consistent so I can spend more time doing what I enjoy (tinkering) instead of what I don't (re-configuring machines).

If you're looking for a complete home configuration, you can check out mine [here](https://github.com/Hoverbear-Consulting/flake/blob/89cbf802a0be072108a57421e329f6f013e335a6/users/ana/home.nix).

Here's what it looks like:

{{ figure(path="gnome.jpg", alt="My GNOME configuration", colocated=true, style="max-height: 100%") }}
