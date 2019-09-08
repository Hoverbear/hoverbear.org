+++
title = "It's a Let's Encrypt Beta!"
aliases = ["2015/10/28/Lets-Encrypt/"]
layout = "blog/single.html"
[taxonomies]
tags = [
  "Tooling",
]
[extra]
image = "cover.jpg"
+++

I was privileged to recieve one of the early [Let's Encrypt](https://letsencrypt.org/) beta certificates for [https://hoverbear.org](https://hoverbear.org/). I had an easy and fun time setting it up this evening on my [Funtoo Container](http://www.funtoo.org/Funtoo_Hosting) and wanted to quickly jot down how to!

<!-- more -->

## Get 'er Done

I first needed some prerequisites (I already had `nginx` installed):

```bash
sudo emerge -vqa augeas python-augeas dialog
```

Then, following the instructions provided:

```bash
git clone https://github.com/letsencrypt/letsencrypt
cd letsencrypt
./letsencrypt-auto --agree-dev-preview --server \
  https://acme-v01.api.letsencrypt.org/directory auth
```

From here you'll be brought to something that looks like a `make menuconfig` when building your own kernel... But a lot easier. From here you have two options, "Manual" and "Standalone".

**Manual** asks you for your domain then tasks you with the job of hosting a file under something like `$YOUR_DOMAIN/.well_known/acme-challenge/$KEY`.

**Standalone** will make an effort to automatically verify your domain for you by hosting it's own web server. (*You'll need to stop your existing `nginx` server if you have one.*)

## Gotchas

Let's Encrypt only issues certificates that are good for 90 days, so you need to regularly renew! There is a [MWoS'2015 Project](https://wiki.mozilla.org/Security/Automation/Winter_Of_Security_2015#Certificate_Automation_tooling_for_Let.27s_Encrypt) to make this renewal automated.
