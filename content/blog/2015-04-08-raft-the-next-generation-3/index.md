+++
title = "Raft: Status Update"
aliases = ["2015/04/08/raft-the-next-generation-3/"]
template = "blog/single.html"
[taxonomies]
tags = [
  "Raft",
  "Rust",
]
+++

In order to celebrate the new [beta](http://blog.rust-lang.org/2015/04/03/Rust-1.0-beta.html) release of Rust, and as part of reporting requirements for my class, I'm happy to write to you regarding [hoverbear/raft](https://github.com/hoverbear/raft)!

<!-- more -->

# A Recap

In January, 2015, a undergraduate (me) at the University of Victoria set out on a quest to implement the [Raft Consensus Algorithm](http://raftconsensus.github.io/) in Rust, an experimental language in shepherded by Mozilla Research.

If you don't know what Raft is, please take a look at [the secret lives of data](http://thesecretlivesofdata.com/raft/). If you don't know what Rust is, please feel encouraged to follow along at [the intro](http://doc.rust-lang.org/nightly/intro.html).

Back in february I had a [first prototype](http://hoverbear.org/2015/02/24/raft-update-3/) working. It was a partial implementation and some subtle logic flaws have been found in the reworking of the code.

> You can play with the very first prototype [here](https://github.com/hoverbear/raft/tree/first-prototype) updated for a recent nightly.

# Where We're Heading

With the help of [Dan Burkert](https://github.com/danburkert/) several dramatic architecture changes have occured.

Summarily, the second prototype builds from the first in the following ways:

* The [mio](https://github.com/carllerche/mio) **Asynchronous Event Loop** backs the library, providing
  it with event driven sockets and timers. This removes the `loop {}` and
  reduces demands on the system by using things like `epoll`.
* **Communication is over TCP**, as opposed to UDP in the first prototype. It
  was determined that the additional costs of TCP were worth its benefits
  provided connections to other nodes could be maintained for multiple
  communications. This improves reliability of communication, ease of
  understanding, and opens the door for encrypted communication at a later date.
* For more efficient communication, **Cap'n Proto is used** to facilitate
  communication between nodes. This dramatically reduces the amount of data
  which needs to be sent compared to the first prototype, which uses JSON.
* The **Replicated Log is abstracted from the library** allowing the client to
  provide their own backing storage for the log in the fashion of their choosing.
* A **`Raft` type is now provided to the consuming application** which
  dramatically simplifies client communication with the cluster. As a result of
  this, all client requests require a network trip, but in the vast majority of
  cases, this was required regardless, since all client requests must go to the
  leader.
* The **State Machine abstraction has been improved** in order to facilitate
  more useful consumption of the library. The first prototype's interface was
  determined to be insufficient to provide things like *Log Compaction*, an
  optional feature of Raft, in the future.

This changes *are still not done*, as they have required a considerable amount of work, both on our code and on upstream libraries.

As a result of this project, several pull requests to upstream projects have
been created and merged.

Merged pull requests by Dan Burkert:

* [impl `::std::error::Error` for `capnp::Error`](https://github.com/dwrensha/capnproto-rust/pull/30)
* [Implement `std::error::Error` for `std::sync::mpsc` error types](https://github.com/rust-lang/rust/pull/23125)

Merged pull requests by Ana Hobden:

* [Move to `&mut s[..]` syntax](https://github.com/dwrensha/capnproto-rust/pull/35)
* [Update `std::error` example](https://github.com/rust-lang/rust/pull/23836)
* [Add `Read` and `Write` to `RingBuf`](https://github.com/carllerche/bytes/pull/12)
* [Add docs for `NonBlock<TcpListener>::accept()`](https://github.com/carllerche/mio/pull/144)
* [Implement `collect()`](https://github.com/carllerche/syncbox/pull/13)
* [Derive not Deriving](https://github.com/rust-lang/rustc-serialize/pull/30)

# Thanks

At this time I'd like to personally extend thanks to the following people:

* David Renshaw ([@dwrensha](https://github.com/dwrensha/))
* Carl Lerche ([@carllerche](https://github.com/carllerche/))
* Dan Burkert ([@danburkert](https://github.com/danburkert/))

For their professionalism, mentorship, and community involvement. One of my favorite things about the Rust community is just how great it is. Stop by on [IRC](https://client01.chat.mibbit.com/?server=irc.mozilla.org&channel=%23rust) sometime!

I'm having a tremendous amount of fun on this project and I'm learning so much. I can't wait to wrap up my semester to get back to work on Raft!

> You can get involved with Raft [here](http://github.com/hoverbear/raft). Or join the Reddit discussion here.
