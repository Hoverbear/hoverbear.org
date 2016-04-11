---
layout: page
title: "Projects"
---

Maintaining projects is no small task, as my experience has taught me. Working with others (and their code) teaches you much though, and helps you become a better person yourself.

I hope to add to this list in the future.

## [Raft-rs](https://github.com/hoverbear/raft-rs) ##

Started as a result of a final project for a Distributed Systems class, our `raft-rs` library has been one of my greatest learning experiences. Indeed, there has been quite a [story](/tag/raft/) attached to it! It's been truly an honor and pleasure to work with the members of the Rust networking community since the early 0.7 Rust nightly builds up until the current version of Rust.

Raft itself is an algorithm enabling replicated state machines, and is highly useful in a distributed systems context. Our implementation is highly faithful to the algorithm defined in the original paper. We took the opportunity to experiment with technologies such as the [`mio`](https://github.com/carllerche/mio) asynchronous event loop and [Cap'n Proto](https://github.com/dwrensha/capnproto-rust) which was highly rewarding.

I'm looking forward to improving the library and helping it become a well regarded package in the community.

## [Rust-Rosetta](https://github.com/Hoverbear/rust-rosetta) ##

[Rosetta Code](http://rosettacode.org/) maintains a gigantic list of common tasks and problems to be solved in different programming languages. Inspired by [this issue](https://github.com/rust-lang/rust/issues/10513) myself and some other community members have been working to implement these problems in a way that allows them to be tested and maintained cleanly.

## [Heroku-buildpack-rust](https://github.com/Hoverbear/heroku-buildpack-rust) ##

Realizing the need for a way to deploy Rust applications to [Heroku](http://heroku.com/) I went about assembling a proper, well tested build pack. The experience taught me much about the inner workings of various cloud services. I also had the opportunity to interface with some (fantastic) people at Heroku.

## [The Gathering Our Voices System](https://github.com/BCAAFC/Gathering-Our-Voices) ##

The [BCAAFC](http://bcaafc.com/) hosts an annual Aboriginal Youth Conference which I have been involved with since the 2012 event. Built almost entirely by me the site features a basic CMS and full workflow and management systems for volunteers, delegates, and facilitators.

These events brought together (in some cases) over 2000 attendees and impacted many lives. There are some [posts](/tag/bcaafc/) about the events.

## [BadSSL](http://badssl.com/) ##

I became involved with the BadSSL project through Mozilla's Winter of Security and really enjoy working with April King and Lucas Garron on it. BadSSL has a sort of menagerie of both naught and nice SSL certificates that allows for users to test their implementations against.
