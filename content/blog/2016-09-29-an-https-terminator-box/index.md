+++
title = "An HTTPS Terminator Box"
aliases = ["2016/09/29/an-https-terminator-box/"]
layout = "blog/single.html"
[taxonomies]
tags = [
  "Infrastructure",
  "Tooling",
]
[extra]
[extra.image]
path =  "cover.jpg"
photographer = "贝莉儿 NG"
+++

Over the last couple days at [asquera](http://asquera.de/) we've been on a retreat at the [Landhaus Fredenwalde](http://landhaus-fredenwalde.de/). It's really beautiful out here and it's given me a chance to work on a few small projects which I've been wanting to explore for awhile now.

Anyways, yesterday I set up a system that uses [Ansible](https://www.ansible.com/), [Let's Encrypt](http://letsencrypt.org/), [nginx](nginx.com), and [DigitalOcean](http://digitalocean.com/) to terminate HTTP and proxy requests to arbitrary hosts. The intended use case for this is to have [Github Pages](http://pages.github.com/) sites able to be dropped onto a custom domain that is SSL enabled, but there are many other use cases which I haven't experimented with (yet).

I was, primarily, interested in exploring using Ansible and DigitalOcean. It worked out quite well [http://hoverbear.org/](http://hoverbear.org/) is running on it at the moment!

<!-- more -->

Without further ado, you can check out the repository [here](https://github.com/Hoverbear/https-terminator#https-terminator). Trying it out on a test subdomain should be quite cheap (in the order of a few cents) and it's rather interesting to poke at.

## On Ansible

I've had some experience with [Puppet](https://puppet.com/), [Chef](https://www.chef.io/), and [Terraform](http://terraform.io/) in different capacities however I had only ever played with Ansible in a minimal fashion. In particular I'd only used Ansible as part of some course work on the [GENI Experiment Engine](http://gee-project.org/) which gives you slices of machines distributed around North America. I liked my experience and after a recent talk at the [Berlin DevOps summit](http://berlinops.de/) I was inspired to try it more.

So what's the differentiator between it and the others? Well the big differences are:

* It is agent-less. Only Python and SSH are required. Puppet and Chef both require agents.
* It's declarative, so there's no complex scripts happening. Chef is scriptable in Ruby, Puppet is also declarative.
* It's just YAML, not some custom syntax. Puppet uses it's own special syntax.
* It has a broad scope, doing things from creating cloud VMs to copying files. Terraform is limited to infrastructure, Puppet and Chef don't do infrastructure as part of their standard package.
* It isn't particularly opinionated about file structure. Chef and Puppet are a bit picky about how you organize things.

So that's basically it! Puppet, Chef, and Ansible all *essentially* address the same problems in different fashions and they all do so in a perfectly acceptable manner. I think it's pretty much down to personal opinion and experience.

As for me, I'll be using Ansible on my next few projects to learn more about it. I think I prefer it.
