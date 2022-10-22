+++
title = "New Roots part 3, Services & Hardening"
published = "false"
template = "blog/single.html"
[taxonomies]
tags = [
  "Infrastructure",
  "Arch Linux",
]
[extra]
[extra.image]
path =  "cover.jpg"
photographer = "Lucas Neasi"
+++

This is the third in a series of posts about getting settled into a server. First we talked about [choosing a server](/2016/05/06/new-roots-1/), then we talked about [installing a base OS on a dedicated server](/2016/05/06/new-roots-2/). In this post we'll discuss configuring, securing, and hardening our server.

In our last post we left our new server in a very, very minimal state. Heck, we didn't even tell it it's own name! In this post we'll talk about configuration. Throughout this process we're going to try to keep things simple and tightly knit. Through most of this guide you'll need to be using `sudo` or acting as `root`.

<!-- more -->

I'm purposely choosing some things I'm not familiar with to learn as I go, so please feel free to offer any advice you might have.

## Hostname

We can set the hostname with the following command:

```bash
HOSTNAME=silicon
hostnamectl set-hostname $HOSTNAME
```

This writes the hostname to `/etc/hostname`. After you'll want to look in `/etc/hosts`. Here's what mine ended up like after I was done editing it. I'm setting up a host called `silicon` on the `hoverbear.org` domain.


```
#
# /etc/hosts: static lookup table for host names
#

#<ip>	    <hostname.domain.org>	     <hostname>
127.0.0.1       silicon.local  silicon
::1             silicon.local  silicon
138.201.63.106  silicon.hoverbear.org    silicon
```

You can test that the local name is working with `ping $HOSTNAME`.

Now that our server thinks it's `$HOSTNAME` we need to tell everything else in the world that it is! If you happen to have a domain name, you should go to your provider's DNS console and route `$HOSTNAME.$DOMAIN.$TLD` to your device's IP address. You can find this with `ip addr`.

For me that looked like adding a line to a table with the following information:

```
silicon     138.201.63.106      A (Address)
```

Go make yourself a tea, then try pinging your server from a different machine a few minutes later.

```bash
FQDN=silicon.hoverbear.org
ping $FQDN
```

Once it starts working you're all set with your domain name! Do note it can take up to 24 hours for global DNS propagation.

## Time

One choice which may bring up confusion is the timezone to set your server to. If you're only going to be hosting services in one time zone you may wish to simply set it to that. If you provide services internationally the question becomes more unclear. One option is UTC.

One thing to consider while evaluating your options on time is to consider how you'll be hosting your services. Later we'll talk about using containers to host your services, and these can all operate on their own timezones. You can review timezones available with `timedatectl list-timezones`.

Properly designed programs will store timezones as part of their dates, but not all programs are properly designed. Changing your timezone later can temporarily cause rather strange issues, so be forwarned.

I'm going to just choose my current local time for now. Since my root host won't be running any time sensitive services I can change it without worrying too much.

```bash
timedatectl set-timezone Canada/Pacific
```

Since we're running a server that will, ultimately, be responsible for possibly time-sensitive data it might be a good idea to ensure we have accurate times. In order to do this we'll enable an `ntp` service.

```bash
timedatectl set-ntp true
```

## A Simple Firewall

Most modern kernels come built in with `iptables` and `nftables` support already. In Arch, `iptables` is pulled in as part of base. `nftables` is a newer 'spiritual successor' to `iptables` however there is little practical real world documentation. Since some of the things we'll be doing later on will be utilizing `iptables` it's probably a good idea to use that.

There is a [menagerie](https://wiki.archlinux.org/index.php/Firewalls#iptables) of different frontends for `iptables` that put a layer between you and it. However `iptables` isn't that difficult to understand and has some great [documentation](https://wiki.archlinux.org/index.php/Iptables). Learning how to understand what's happening in `iptables` will make using even frontends easier later on, if you even choose to use them.

We'll be referencing the [Simple Stateful Firewall](https://wiki.archlinux.org/index.php/Simple_stateful_firewall) for our initial setup.

Since we're currently on a remote device over SSH we need to be careful not to lock ourselves out. So let's set some basic filter settings in `/etc/iptables/iptables.rules`:

```bash
*filter
### Defaults for the chain.
# Drop anything that we don't catch from input.
:INPUT DROP [0:0]

# We're not a router, we shouldn't forward anything along a NAT.
:FORWARD DROP [0:0]

# We trust things running on this machine, so accept them all.
:OUTPUT ACCEPT [0:0]

# User defined chains.
:TCP - [0:0]
:UDP - [0:0]

# Accept already established or related connections.
--append INPUT --match conntrack --ctstate RELATED,ESTABLISHED --jump ACCEPT

# Accept anything from the local loopback.
--append INPUT --in-interface lo --jump ACCEPT

# Drop any invalid packets. We can't reject since there's no valid way to reject.
--append INPUT --match conntrack --ctstate INVALID --jump DROP

# Accept any pings.
--append INPUT --protocol icmp --match icmp --icmp-type 8 --match conntrack --ctstate NEW --jump ACCEPT

# Attach the user defined chains (UDP, TCP) to valid connections on the
# respective protocol. Recall that anything established is already accepted.
--append INPUT --protocol udp --match conntrack --ctstate NEW --jump UDP
--append INPUT --protocol tcp --tcp-flags FIN,SYN,RST,ACK SYN --match conntrack --ctstate NEW --jump TCP

# Reject TCP connections with TCP RESET packets and UDP streams with ICMP port
# unreachable messages if the ports are not opened.
--append INPUT --protocol udp --jump REJECT --reject-with icmp-port-unreachable
--append INPUT --protocol tcp --jump REJECT --reject-with tcp-reset

# Reject all remaining incoming traffic with icmp protocol unreachable messages.
--append INPUT --jump REJECT --reject-with icmp-proto-unreachable

### TCP Chain
# Allow SSH connections.
--append TCP --protocol tcp --dport 22 --jump ACCEPT

COMMIT
```

Now you can start and get the status of the `iptables` service.

```bash
systemctl start iptables
systemctl status iptables
```

Now try ending your `ssh` session and hopping back in. If it didn't work you can just reset the machine and try reconfiguring. If it did work then we can enable the service on boot.

```bash
systemctl enable iptables
```

At this point you can review your current settings and see various usages with `iptables -nvL`:

```
Chain INPUT (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
  215 18609 ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate RELATED,ESTABLISHED
    0     0 ACCEPT     all  --  lo     *       0.0.0.0/0            0.0.0.0/0           
    0     0 DROP       all  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate INVALID
    0     0 ACCEPT     icmp --  *      *       0.0.0.0/0            0.0.0.0/0            icmptype 8 ctstate NEW
    1   439 UDP        udp  --  *      *       0.0.0.0/0            0.0.0.0/0            ctstate NEW
    4   188 TCP        tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp flags:0x17/0x02 ctstate NEW
    1   439 REJECT     udp  --  *      *       0.0.0.0/0            0.0.0.0/0            reject-with icmp-port-unreachable
    2    80 REJECT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            reject-with tcp-reset
    0     0 REJECT     all  --  *      *       0.0.0.0/0            0.0.0.0/0            reject-with icmp-proto-unreachable

Chain FORWARD (policy DROP 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 146 packets, 20108 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain TCP (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    2   108 ACCEPT     tcp  --  *      *       0.0.0.0/0            0.0.0.0/0            tcp dpt:22

Chain UDP (1 references)
 pkts bytes target     prot opt in     out     source               destination
```

As you can see from the `pkts` column, our rule in `TCP` got used for an `ssh` connection, and the rule for already established connections is also being used.

## Hardening

Servers get attacked, it's a fact of life. Let's take some simple steps to help build up a bit of security for ourselves. First let's set some flags in `/etc/sysctl.d/50-hardening.conf`:

```bash
# Only root can see dmesg
kernel.dmesg_restrict = 1
# Restrict kernel pointer access.
kernel.kptr_restrict = 1

# TCP SYN cookie protection (default) helps protect against SYN flood attacks
# only kicks in when net.ipv4.tcp_max_syn_backlog is reached
net.ipv4.tcp_syncookies = 1

# Protect against tcp time-wait assassination hazards drop RST packets for
# sockets in the time-wait state (not widely supported outside of linux,
# but conforms to RFC)
net.ipv4.tcp_rfc1337 = 1

# Sets the kernels reverse path filtering mechanism to value 1, it will do
# source validation of the packet's recieved from all the interfaces on the
# machine protects from attackers that are using ip spoofing methods to do harm
net.ipv4.conf.all.rp_filter = 1
net.ipv6.conf.all.rp_filter = 1

# We will be forwarding for IPv4 to containers. Enable this.
net.ipv4.ip_forward = 1

# Ignore echo broadcast requests to prevent being part of smurf attacks
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus icmp errors
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Protect against some hardlink and symlink vulnerabilities.
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
```

Much of this configuration was taken from the [security guide](https://wiki.archlinux.org/index.php/Security). Now you can apply the changes with `systemctl --system`.


## DNS and Name Resolution

It's now time to properly configure `systemd-resolved`. First we'll link its configuration into the old `/etc/resolv.conf` location for compatability [reasons](https://wiki.archlinux.org/index.php/systemd-networkd#Required_services_and_setup).

```bash
rm /etc/resolv.conf
ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
systemctl restart systemd-resolved
```

Next we'll go into `/etc/nsswitch.conf` and set up to local DNS stub resolver. Change this line:

```diff
+ hosts: files mymachines resolve myhostname
- hosts: files dns myhostname
```

Now we can go about creating and modifying files in `/etc/systemd/network/`. Before going about this it's a good idea to review your network adapters and check out `man systemd.network`. You can do this with `ip addr`. You should see a `lo` and some adapter starting with `enp`. The `enp` prefixed adapter is your physical adapter.

We can go back and review our previous `/etc/systemd/network/physical.network` now. Some changes can be made:

```bash
[Match]
# Make sure this matches your adapter from the ip addr command
Name=enp*

[Network]
DHCP=ipv4
# Use global NTP pools
NTP=0.pool.ntp.org
NTP=1.pool.ntp.org
NTP=2.pool.ntp.org
NTP=3.pool.ntp.org
```

Then we'll configure `/etc/systemd/resolved.conf`:

```bash
[Resolve]
# Specify Google's DNS instead of whatever the default picked by DHCP is.
DNS=8.8.8.8
FallbackDNS=8.8.4.4
LLMNR=true
```

## Reboot & Tea Time

At this point we've tinkered with enough things it's a good idea to verify everything is working as intended still. Give your system a `reboot`, go make yourself a cup of tea (servers take time to reboot), and verify that you can reconnect.

So far we've set up a basic firewall, configured time syncronization, added some kernel parameters, and added some basic configuration to our physical network adapter. These are things that you'll likely want to do on your server regardless of what it's final purpose is, and even if you do need to change them this gives you a good basis.

At this point our configuration is roughly as so:

```
internet -> host { iptables -> ssh }
```

Our host is configured through `systemd-networkd` and name resolution is augmented by `systemd-resolved`. This configuration places us in a great position to use container based services.

## Adding a New Service (mosh)

We'll discuss setting up and networking various services at length in future posts, including example `nginx`, `postgres`, `nodejs` and `rust` service deployments. We'll end up using containers for these, the idea of using containers for these services is a choice of isolation and modularization. We'd, ideally, like to keep our 'root' system as simple and secure as possible, it shouldn't have the job of hosting any public facing services other than `ssh` and `nginx`, and we'll only use `nginx` to proxy requests to other HTTP servers.

For me there is one exception to this rule, [`mosh`](https://mosh.mit.edu/). `mosh` completely changed my experience using `ssh`, especially over unreliable or mobile connections (such as a laptop). It works by transporting your `ssh` session data over UDP, and works through changes in IP or situations of large lag.

The process for adding any new service will be similar, so even if you're not interested in installing `mosh` it's good to be familiar with it. We'll use it as an example below.

**Install:** You should choose a reliable, secure source for your service. You should always prefer the official Arch repositories over the AUR or a third party repository, especially on the 'root' of the server.

```bash
pacman -S mosh
```

**Discover:** Most externally facing services require a port to bind to (if they're TCP), or recieve from / send through (if they're UDP). You may recall we set up our firewall to accept all outgoing connections, so we only need to configure it to accept incoming data. You can generally discover this by looking in their respective `man` pages, website, or the configuration itself.

`mosh` uses ports starting at `60000` and going up to `60999` if lower numbered ports are not available. It's pretty reasonable to assume that we'll never have more than 100 `mosh` sessions, so we only need to allow the lower 100 ports.

**Accept:** In order to accept data on these ports we'll open them up by adding the following line *near* the bottom of our `/etc/iptables/iptables.rules` file, *before* the `COMMIT` line.

```bash
# Allow MOSH connections.
--append UDP --protocol udp --dport 60000:60100 --jump ACCEPT
```

Then you can restart the firewall with `systemctl restart iptables`.

**Test:** At this point if your new service has a daemon to run you should start it with the appropriate `systemctl start $SERVICE` command. Then take a moment to test your service and make sure it works as expected.

With `mosh` there is no daemon, we just test by trying to use it!

```bash
HOSTNAME=silicon.hoverbear.org
mosh $HOSTNAME
```

**Enable:** Once you know things are working correctly we can enable it to start at boot if desired with `systemctl enable $SERVICE` Since `mosh` has no related daemon we don't need to do this.

**Verify:** At this point my `mosh` service works fine, and we can verify that the firewall is catching this by reviewing `iptables -nvL` and checking out our `UDP` chain:

```
Chain UDP (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    2   217 ACCEPT     udp  --  *      *       0.0.0.0/0            0.0.0.0/0            udp dpts:60000:60100
```

As you can see here, the rule was used twice, which means it's working! At this point, we're done setting up the new service. We'll have a chance to practice this more in future posts when we're configuring various serices.

For our [next post](/2016/05/09/new-roots-4/) we'll explore nice ways to personalize your server environment and make it feel like home. Remember, there's no place like `127.0.0.1`. :)
