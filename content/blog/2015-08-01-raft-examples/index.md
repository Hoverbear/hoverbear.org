+++
title = "Raft Progress & Examples!"
aliases = ["2015/08/01/raft-examples/"]
layout = "blog/single.html"
[taxonomies]
tags = [
  "Rust",
  "Raft",
  "UVic",
]
[extra]
image = "cover.jpg"
+++

We've also got couple nice working examples! Yes, they're ready to play with!

> Can't wait, need code? Visit [Raft](https://github.com/hoverbear/raft) and check out the `examples/` directory!

<!-- more -->

# Progress Report #

The core Raft consensus algorithm now is quite functional! We're still lacking log compaction (but have support for snapshotting already prepared) and have not implemented dynamic membership changes. These things are on our [road map](https://github.com/Hoverbear/raft/milestones/Full%20Paper%20Implementation)!

We've been building more tests and examples recently, Dan landed [this bundle](https://github.com/Hoverbear/raft/pull/64) which got us into a good state! Next I landed [`query`](https://github.com/Hoverbear/raft/pull/67) and some [example expansion](https://github.com/Hoverbear/raft/pull/73) which gave us some examples that work!

## Examples ##

There are now [`register`](https://github.com/Hoverbear/raft/blob/master/examples/register.rs) and [`hashmap`](https://github.com/Hoverbear/raft/blob/master/examples/hashmap.rs) examples in the `examples/` directory. These show simplistic examples of the flexibility of the module we've created. There are plentiful comments in the examples and our module documentation is definitely getting better.

The [`register`](https://github.com/Hoverbear/raft/blob/master/examples/register.rs) example uses [TyOverby's `bincode`](https://github.com/TyOverby/bincode) and replicates a simple buffer.

The [`hashmap`](https://github.com/Hoverbear/raft/blob/master/examples/hashmap.rs) example demonstrates [Erickt's `serde`](https://github.com/serde-rs/serde) and replicates a common `HashMap` over a collection of nodes.

Please feel encouraged to give feedback and experiences if you play some!

## Distributed Examples ##

I'll be working on some distributed testing and scripting for use with Puppet in the future as I fiddle more with the excellent [GEE](http://gee-project.org).

## SOSP'2015 ##

We've submitted a poster to [SOSP'2015](http://www.ssrc.ucsc.edu/sosp15/callForPosters.html)! Wow! Check out the [issue](https://github.com/Hoverbear/raft/issues/69) to see what we submitted.

It was fun and we went for a "old school cereal box" feel like the [Cap'n Proto site](http://capnproto.org/).


> [Psst](http://www.meetup.com/Rust-Bay-Area/events/219696985/), [there's something brewing on the horizon...](https://github.com/Hoverbear/raft/issues/74)
