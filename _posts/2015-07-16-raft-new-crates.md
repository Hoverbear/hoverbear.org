---
layout: post
title: "Raft: New Crates!"
author: "Andrew Hobden"
tags:
 - Rust
 - Raft
---

We've been resoundingly busy with our [Raft](http://raftconsensus.github.io/) implementation after a brief period of calm in the early summer! I'll be posting a few bits over the next weeks to help people both learn Rust, and learn about Raft!

As a result of Raft development two new crates have been put together for general consumption! Both of these are macro-centric and lead mainly by James.

## A Useful Error Pattern

Working with Raft we discovered a useful error pattern for making use of things like `try!()`. Let's quickly recap on why error handling can be a pain sometimes.

Let's say you're off happily using `.read()` on some file descriptor (maybe a `TcpStream`) and than performing some action which may also result in an error. So you write a function like so:

	use std::io::Read;
	fn read_and_action<R: Read>(reader: R) -> Result<String, _> {
    	let buf = Vec::with_capacity(10);
        try!(reader.read(&mut buf));
        try!(String::from_utf8(buf))
    }

But wait! There is a problem here! The first `try!()` and the second `try!()` have *different errors* that they might return. **This won't work.** Even worse, in a sufficiently complex library or application there can be many `Error` types in play!

We identified this very early in Raft and came up with a eloquent solution: Create an `Error` composed of the various possible errors! James went ahead and actually made a [fantastic macro](https://github.com/james-darkfox/rs-wrapped_enum-macro) that you can use to do the same easily!

    /// A simple convienence type.
    pub type Result<T> = std::result::Result<T, Error>;

	// From crate: https://github.com/james-darkfox/rs-wrapped_enum-macro
    wrapped_enum!{
        #[derive(Debug)]
        pub enum Error {
        	// Cap'n Proto Errors
            CapnProto(capnp::Error),
            // Cap'n Proto schema errors
            SchemaError(capnp::NotInSchema),
            // std::io errors
            Io(io::Error),
            // Our very own!
            Raft(RaftError),
        }
    }

    impl fmt::Display for Error {
        fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
            match *self {
                Error::CapnProto(ref error) => fmt::Display::fmt(error, f),
                Error::SchemaError(ref error) => fmt::Display::fmt(error, f),
                Error::Io(ref error) => fmt::Display::fmt(error, f),
                Error::Raft(ref error) => fmt::Debug::fmt(error, f),
            }
        }
    }

With this machinery in place our previous example starts to work, fantastic! This has saved us so much headache and complication in our code. Want it? Click one of the badges below!

[![](https://img.shields.io/crates/v/wrapped_enum.svg)](https://crates.io/crates/wrapped_enum)
[![](https://img.shields.io/crates/d/wrapped_enum.svg)](https://crates.io/crates/wrapped_enum)

## Scoped Logging

Okay, let's take a minute to remember how frigging awesome the [`log`](https://crates.io/crates/log) crate is. If you've got a project, large or small, this crate is super handy for helping trace, debug, and log whatever you need and to do it only when needed! The best part about the log crate is that when logs are off it's a simple `noop`.

One problem we identified, however, was that sometimes it was very difficult to identify the source of a log message. Asking "Did it come from `foo` or `bar`?" is only fun so many times.

James and Dan put together the [`scoped_log`](https://github.com/james-darkfox/rs-scoped_log) crate to help with this. Check out the documentation there for a usage example.

When we use this crate with tests (which makes it all that much more awesome!) we use the following macro.

    /// Prepares the environment testing. Should be called as the first line of every test with the
    /// name of the test as the only argument.
    #[cfg(test)]
    macro_rules! setup_test {
        ($test_name:expr) => (
            let _ = env_logger::init();
            push_log_scope!($test_name);
        );
    }

Now our logs look like this:

    INFO:raft::replica: test_apply_client_message: ElectionTimeout
    INFO:raft::replica: test_election_3: ElectionTimeout
    INFO:raft::replica: test_election_2: ElectionTimeout
    INFO:raft::replica: test_apply_client_message: transitioning to Leader
    INFO:raft::replica: test_election_5: ElectionTimeout
    INFO:raft::replica: test_election_5: transitioning to Candidate
    DEBUG:raft::replica: test_election_5: Replica { id: 3, state: Follower, term: 0, index: 0 }: RequestVoteRequest from Replica { id: 0, term: 1, latest_log_term: 0, latest_log_index: 0 }

Much more context that we *barely* have to tool. Fantastic! This crate even maintains the same `noop` characteristic of the `log` crate which it heavily relies on. Want it?

[![](https://img.shields.io/crates/v/scoped_log.svg)](https://crates.io/crates/scoped_log)
[![](https://img.shields.io/crates/d/scoped_log.svg)](https://crates.io/crates/scoped_log)

## Travis & Cargo!

If you've read any of my other articles you probably know I **love** tooling and automation. After my [Rust, Travis, and Github Pages](http://hoverbear.org/2015/03/07/rust-travis-github-pages/) article [Huon](https://github.com/huonw) created the fantastic [`travis-cargo`](https://github.com/huonw/travis-cargo) tool! It's incredible!

With its help we've moved to a `sudo`-less build and overall things work much better. I'll talk more about out tooling and infrastructure in a later post!

# Aside: Contributors!!!

We now have 3 whole code contributors to Raft! This includes [Dan Burkert](https://github.com/danburkert), [James McGlashan](https://github.com/james-darkfox), and [myself](https://github.com/hoverbear/) (Andrew Hobden). I'd like to thank both James and Dan for their awesome work, interest, and mentorship!
