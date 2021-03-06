+++
title = "New Roots part 1, Choosing a Server"
published = "false"
template = "blog/single.html"
[taxonomies]
tags = [
  "Infrastructure"
]
[extra]
[extra.image]
path =  "cover.jpg"
photographer = "Todd Quackenbush"
+++

This is the first in a series of posts where we'll discuss the process of obtaining, setting up, and settling into a new headless server. Along the way we'll install Linux, configure firewalls and web servers, set up virtual machines, tinker with system knobs, explore automation tools, and generally have a great time.

In this post, We'll discuss things to keep in mind when searching for your own hosting, things to look for, and the differences between distinctions.

This series is not intended to be a comprehensive guide. These are just the notes and rambling of a hobbyist server admin who's loved tinkering for over a decade. I'm writing these both for my own future reference, and so my readers can suggest improvements! As always, comments are welcome via [email](mailto:ana@hoverbear.org).

<!-- more -->

## Background and Goals

I recently obtained a new [server from Hetzner](https://www.hetzner.de/de/hosting/produkte_rootserver/ex41sssd) and wanted to take time to document how I setup and configure it. I like writing too, so I figured a blog series is really the best option! Perhaps I'll help someone else as well.

In starting this process I realized that many people aren't really sure where to start. The process can actually be pretty overwhelming. Just what is a 'server' anyways? What is most appropriate for your application, [Ethical Hosting](http://www.ethicalhost.ca/ethical-webhosting-plans.html), [Funtoo Containers](http://www.funtoo.org/Funtoo_Containers), or something like mine? What's it like to have a server? How do we interact with it? How do we shop for one?

## What's a Server?

The word conjures up many fantastical images in our heads. But let's face it, at it's core a server is just a computer. Sure, it's a lot different than the ones in your fridge, but it's not all that much different from your phone in many respects.

Generally, when we speak of servers we're referring to them that way because they **receive** requests and **serve** them. For most of us, this concept works best by going "Okay say you visit a website," and that diagram has these two (very simplified) steps:

```
You -> Internet -> Server
You <- Internet <- Server
```

The 'server' is always located on a physical machine running somewhere in the world, this is the **metal** which we're running on. A server could be a whole machine, a virtualized machine, or they could just be a simple daemon process. They can be roughly anologized as real estate. Each has different qualities to observe.

### The Dedicated Server

> The single-family home.

It's possible to obtain use of an entire 'server' machine for yourself. These are typically either homebrew servers, servers purchased and co-located in datacenters, or rented units owned by a provider. Typically dedicated servers are (by far) the most powerful, and typically have a great bang for your buck since they're mostly DIY.

These units are great for people who like to experiment, tinker, and manage their own space. Expect to be responsible for your own backups, your own system configuration, and your own troubleshooting. In return, you get absolute freedom. Install anything you want, break anything you want, do anything you want.

Most dedicated server providers are data center operators or companies who have partnerships with them. Example providers are [1984](https://www.1984.is/) and [Hetzner](http://hetzner.de/), both recommended by persons I respect.

As a computer scientist, I treat my personal server like a laboratory, and I'm opting for this choice.

### The Virtual Private Server

> The condo.

Often it's not necessary to have all the raw power a dedicated server can offer. You may only need a couple GB of RAM, or want to keep costs low. Virtual Private Servers, or VPS are in a good space this way. It's entirely possible to spend under $20 USD a month on hosting.

These units are part of multi-tenant dedicated servers, and you get a fair 'slice' of the server for your monthly cost. In most cases you don't even notice your neighbors, but rarely you get bad luck and have to share space with a bad neighbor.

VPS come in a few varieties: KVM, container, and other. KVM based VPS still allow you to run container systems (such as Docker and Rkt), while a container based VPS actually places you inside one of these. It's also possible to find exotic or esoteric hosting, such as being a Windows Server guest, they might not be the best choice.

The VPS space is filled with great providers. I've personally used [Funtoo Containers](http://www.funtoo.org/Funtoo_Containers) for years and always really enjoyed them. [Linode](http://linode.com/) and [Digital Ocean](http://digitalocean.com/) are also very well known, and both feature locations outside of the US!

Many VPS operators also offer additional features such as snapshot backups and things that dedicated servers leave up to the user.

If you're going to be exploring your first server a VPS is a great way to go, both for cost and abilities.

### The Web host

> The hotel.

Perhaps the most popular offering of hosting, simple web hosting typically involves you recieving an `sftp` account on a server and having access to some of the folder structure. These services are preconfigured with access to PostgresSQL and PHP configured. The service is very similar to what one would experience on [Gitlab](http://pages.gitlab.io/) or [Github](https://pages.github.com/) pages.

These services are typically very inexpensive, however they offer very little in the way of control or flexibility. However if your only interest is hosting a Wordpress site this is a great choice. Not only do most of these services offer automated configuration of things like Wordpress, they also do all the hard work of securing and maintaining it.

At places I've worked we've had great success with the Canadian provider [Ethical Host](http://ethicalhost.ca/). Don't be fooled by the dated website, John (the owner) is extremely competent and very responsive to support.

If your dreams are to have a web presence and tinker around with PHP or themes, this is a great choice.

## Things to look for

There are a few things to be looking for in a server, these points only (really) apply to Dedicated and VPS servers. Web Hosts typically you aren't even told these specifics.

* **Multiple Cores:** Server processors are amazing and if you're investing in a server you likely want the features and power of a proper Xeon core. Prefer a Xeon (or equivalent) over a consumer grade chip. These are generally 4-8 core and offer hyperthreading. If you're not using a dedicated host you likely will only share this processor. That's quite ok.
* **Lots of RAM:** These days it's entirely practical to find dedicated machines with 32+GB of RAM. Virtual Servers typically have very affordable 4GB variants. Remember that RAM won't 'add' speed to your services magically, but if you're running lots of things it will definitely make an improvement.
* **Solid State Drives:** There's an argument for spinning rust, but for most uses you will not need more than perhaps 100GB of storage. Instead of opting for a big disk, opt for a fast disk. If you need bulk storage consider looking for a dedicated storage box or bucket, which are very economical.
* **Reasonable Bandwidth Capacity:** Having fluctuating costs really sucks, so does getting charged for bandwidth. Consider your use case and expected traffic, also consider scaling.
* **Remote Access:** Your server shuts down. How do you turn it back on? How can you get into the bootloader? How can you request USB sticks to be plugged in? These are all questions you need to be able to answer.
* **Data Location:** How does your provider treat your data? What level of privacy can you expect? If you're providing services to minors, marginalized or threatened people, or collecting any personal information you should be aware of the host country's laws. I'd highly suggest staying out of the USA for your hosting options, observing the current saga unfolding around privacy and data ownership.

For all storage and bandwidth related estimations you can consider pictures, songs, presentations/documents as all roughly 5MB. This is generous but you'll be thankful later.

[Next post](/2016/05/06/new-roots-2/) we'll discuss how to install a dedicated host.
