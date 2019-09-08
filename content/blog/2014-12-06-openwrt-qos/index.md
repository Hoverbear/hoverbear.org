+++
title = "OpenWRT QoS"
aliases = ["2014/12/06/openwrt-qos/"]
layout = "blog/single.html"
[taxonomies]
tags = [
  "Tutorials",
  "OpenWRT",
]
+++

Using the setup from my [last](/2014/11/23/openwrt-in-virtualbox/) [two](/2014/12/03/vagrant-clients-for-openwrt-vms/) posts, let's play with some QoS parameters and observe the results.

> The [documentation](http://wiki.openwrt.org/doc/uci/qos) for OpenWRT's QoS is rather lacking, please feel encouraged to improve it as you go!

<!-- more -->

## Prerequisites

Documented [here](http://wiki.openwrt.org/doc/uci/qos), the `qos-scripts` package offers a simple configuration that integrates well with the rest of OpenWRT's UCI (Unified Configuration Interface).

On the router:

	opkg install qos-scripts

As an added side benefit, `qos-scripts` will pull in several dependencies that can be used to further tune our QoS.

## Overview

You can look into `/etc/config/qos` to see the default configuration.

You'll see several `config` block types. Let's take a look at samples.

### Interfaces

	config interface wan
        option classgroup  "Default"
        option enabled      0
        option upload       128
        option download     1024

This is an **interface** definition for `wan`. `wan` is defined in `/etc/config/network`.

* `option classgroup "Default"` defines that we'll use the classes defined in the `config classgroup "Default"` block also in the configuration file.
* `option enabled 0` defines that QoS is currently **not** enabled for the `wan` interface. Meaning this configuration currently doesn't do anything. If it's value was `1` it would be enabled.
* `option upload 128` defines that this interface should only be able to upload at a rate of `128` kilobits/second. (Only for TCP)
* `option download 1024` defines that this interface should only be able to download at a rate of `1024` kilobits/second.

### Rules

	config classify
        option target       "Priority"
        option ports        "22,53"
        option comment      "ssh, dns"
    config classify
        option target       "Normal"
        option proto        "tcp"
        option ports        "20,21,25,80,110,443,993,995"
        option comment      "ftp, smtp, http(s), imap"
    config reclassify
        option target       "Priority"
        option proto        "icmp"
    config default
        option target       "Bulk"
        option portrange    "1024-65535"

`classify` blocks are an *initial, connection-tracked classification*. They are only run on connections which have not been assigned a traffic class already.

`reclassify` blocks can *override* the class on a *per packet* basis without altering the connection's classification.

`default` blocks are fallbacks for everything that has not been marked by a `classify` or `reclassify`.

* `option target "Priority"` means that any connections or packets under this block are placed in the specified class (in the interface's `classgroup`).
* `option ports "22,53"` means that this classifier will only work for connections on port 22 and 53.
* `option comment "ssh,dns"` is a comment about the purpose of the classifier.
* `option proto "tcp"` defines the protocol (`tcp`, `udp`, `icmp`, etc) that this classifier matches.
* `option pktsize "-500"` allows us to define a packetsize to match.

If you're wondering, the `-` in `-500` operates *I think*, on the definition of the corresponding `class`.

## Classgroups

	config classgroup "Default"
		option classes      "Priority Express Normal Bulk"
        option default      "Normal"

`classgroup` blocks are used to define different class groupings. This is only really useful if you wish to have multiple interfaces with different class considerations, for example, you might want `eth1` to have an `ultrapriority` class or something.

### Classes

	config class "Priority"
        option packetsize  400
        option avgrate     10
        option priority    20
	config class "Express"
        option packetsize  1000
        option avgrate     50
        option priority    10
	config class "Normal"
        option packetsize  1500
        option packetdelay 100
        option avgrate     10
        option priority    5
	config class "Bulk"
        option avgrate     1
        option packetdelay 200

`class` blocks are used to define packet classes. Each class is placed inside of a seperate [bucket](https://en.wikipedia.org/wiki/Leaky_bucket).

* `option packetsize 400` defines the size of packets within the bucket.
* `option maxsize 1000` defines the maximum size of the bucket. *(Probably, this isn't specified.)*
* `option packetdelay 100` defines the delay of the packet, in ms.
* `option avgrate 50` defines *some undocumented* parameter in %.
* `option priority 20` is a percentile value specifying the bucket's priority.

# Initial Configuration

As a reminder, here is the configuration of our setup.

{{ figure(path="diagram.jpg", alt="Our setup.", colocated=true) }}

First, we need to pull in `xt_connmark`, which is a depedency for some features of `qos-scripts`:

	modprobe xt_connmark

Then, in `/etc/config/qos` replace the `wan` interface with our various defined interfaces with some modest and determinable differences to test that it works.

	# INTERFACES:
    # Fast client.
    config interface lan1
            option classgroup  "Default"
            option enabled      1
            option upload       256
            option download     2048
    # Slow client. (1/2 speed)
    config interface lan2
            option classgroup  "Default"
            option enabled      1
            option upload       128
            option download     1024
	# The Host. (Big pipes)
    config interface lan3
            option classgroup  "Default"
            option enabled      1
            option upload       4096
            option download     4096


To enable QoS and start it:

	/etc/init.d/qos enable
    /etc/init.d/qos start

Later, to restart it:

	/etc/init.d/qos restart

#### Aside: An Resolved Issue

> When I attempted to use the `pktsize` option in a classifier I recieved yet unresolved errors.

The error was:

	iptables: No chain/target/match by that name.

Inspecting the generated config:

	/usr/lib/qos/generate.sh all

See the script executed along with output (for diagnosing errors):

	/usr/lib/qos/generate.sh all | sh -x

Resulted in:

	# ...
    + iptables -t mangle -A qos_Default -m mark --mark 0/0xf0 -p udp -m length --length 500 -j MARK --set-mark 34/0xff
    iptables: No chain/target/match by that name.
    # ...

I was only able to resolve this by removing the use of `pktsize` in classifiers then restarting the service.

## Testing It

Open up a terminal to use `vagrant ssh test1` and `test2` then, run the following command at approximately the same time (remember to sub in `$TEST3IP`):

	wget $TEST3IP/video.mp4

You should see something like the following:

{{ figure(path="in-action-1.png", alt="In action.", colocated=true) }}

Feel free to cancel them at any time. We only care about the rate right now.

As you can see, `test1` recieved approximately twice the bandwidth of `test2`. Perfect, that's exactly what we wanted.

> Things will not always be exact as there are protocol overheads and other factors in our simulation.

Before going on to more complicated experiments you may want to ensure that the rates are more fair.

# Experimentation

With our QoS system in place, what kind of experiments can we do to the network?

## Favoring Ports

Looking over the default configuration you can see the following config block:

	config classify
        option target       "Priority"
        option ports        "22,53"
        option comment      "ssh, dns"

Which match to the following class:

	config class "Priority"
        option packetsize  400
        option avgrate     10
        option priority    20

This suggests that all traffic over port 22 (The standard `ssh` default) will prioritized as it has the highest priority in the default configuration.

But what if you don't use port 22 for `ssh`? Then this is a silly rule.  You can easily just remap the ports option to `"2222,53"` or something else.

## Limiting a Class Rate

Say we'd like to gaurentee that one class of packets can only take up so much of the total limit of the connection.

First, lets get our `test3` VM serving off multiple ports so we can classify them differently.

In `/etc/nginx/nginx.conf` modify your listen block:

	    server {
          listen       80 default_server;
          listen       8080; # Add this.
          server_name  localhost;
          root /vagrant;
          # ...

Then run `sudo systemctl restart nginx`.

Back on the router, edit `/etc/config/qos` to add two new blocks, a `classify` block and a `class` block. Also make sure that your `lan1` and `lan2` interfaces have the same upload and download so we can use them to test.

	config classify
    	option target  "httpdev"
        option ports   "8080"
        option comment "httpdev"
	config class "httpdev"
    	option packetsize  1500
        option packetdelay 100
        option limitrate   10
        option priority    5

Then in the `classroup "Default"` add `httpdev` to the classes.

Finally, restart the QoS:

	/etc/init.d/qos reload

Then get `test1` to download from port 80, and `test2` to download from port 8080.

{{ figure(path="httpdev.png", alt="httpdev", colocated=true) }}

Attempting to download on port 8080 only resulted in recieving 10% of the available bandwidth, where on port 80 it was able to use the entire link.

## Priorities

Instead of placing a hard limit on the rate a class can achieve, let's instead change the priority it recieves.

On the router, edit `/etc/config/qos`, change the `Normal` class to have a `50` priority, while leaving `httpdev` on `5`.

	config class "Normal"
        option packetsize  1500
        option packetdelay 100
        option avgrate     10
        option priority    50

Then issue `/etc/init.d/qos reload`. To test this, **on one of the `test1` or `test2`** open two connections and attempt to download from both ports.

{{ figure(path="priorities.png", alt="Priorities.", colocated=true) }}

Here I ran two tests, one with downloads on different ports, one with them on the same. Notice how the `8080` download is much slower while there is a download on port `80` happening, but while both at on port `80` they're nearly the same *(except that I couldn't stop both at the same time so the second one I stopped was reading higher then before, they were both in the teens).*

A lone download on port `8080` (and thus of the `httpdev` class) would still be fast if there is no other traffic in the `normal` class, though.

# Further Configuration

While `qos-scripts` provides many simplier facilities for configuring Quality-of-Service in OpenWRT, it is certainly not the be all, end all.

You can also take a much more low-level and fine grained control of how things behave using standard Linux tools. After all, everything in `qos-scripts` is built off `iptables`, `tc`, and other standard tools.

Here are some links to explore further:

* [Network Traffic Control](http://wiki.openwrt.org/doc/howto/packet.scheduler/packet.scheduler) - Configuring your kernel scheduler.
* [Netfilter](http://wiki.openwrt.org/doc/howto/netfilter) - Configuring `iptables` and other things.
* [Bandwidth Monitoring](http://wiki.openwrt.org/doc/howto/bwmon) - Keeping tabs on things.

*A special thanks to the Bergens Banen train for our test material. The cover image of this article is from the video.*
