---
layout: post
title: "Raft Experiences and Repo Made Public!"
tags:
 - Raft
 - Rust
 - CSC466
 - CSC462
---

> TL;DR: I've made [Hoverbear/raft](https://github.com/Hoverbear/raft) publicly available *(It's still not ready)*! Feel encouraged to contribute feedback or code via Github or email!

## Progress

I've been working hard on building a sane, reasonable scaffolding for the codebase. [Last post](/2015/01/25/raft-so-far/) I talked about my first 'go' at designing the data structures and interfaces for the library, here I'll talk a bit about what's changed and why.

### Data Interchange

Probably one of the most interesting (and meaningful) changes I've made was moving my previous enum structs into seperate enums and structs.

Simply, this:

    enum ClientRequest<T> {
        IndexRange {
            start_index: u64,
            end_index: u64,
        },
        AppendEntries {
            prev_log_index: u64,
            prev_log_term: T,
            entries: Vec<T>,
        },
    }

Became this:

    #[derive(RustcEncodable, RustcDecodable, Debug, Clone)]
    pub enum ClientRequest<T> {
        /// Gets the log entries from start to end.
        IndexRange(IndexRange),
        /// Asks the node to append an entry after a given entry.
        AppendRequest(AppendRequest<T>),
    }

    #[derive(RustcEncodable, RustcDecodable, Debug, Clone, Copy)]
    pub struct IndexRange {
        pub start_index: u64,
        pub end_index: u64,
    }

    #[derive(RustcEncodable, RustcDecodable, Debug, Clone)]
    pub struct AppendRequest<T> {
        pub prev_log_index: u64,
        pub prev_log_term: T,
        pub entries: Vec<T>,
    }

So... *Why?* A couple of reasons actually:

1. ~~**Enum structs take the memory of their biggest variant.** This is a minor concern to me as most of my structs are just a few values large, but I understand how this can have an effect and I'd like to follow best practices.~~ [(The change made did not benefit from this. See this comment by Quxxy)](https://www.reddit.com/r/rust/comments/2ux7xo/raft_experiences_part_1_and_repo_made_public/cocqx4d)
2. **You lose type safety.** There is no way to create a function that will only accept a single variant of an enum. You can't, for example, say `fn foo(bar: Option::None) {}`. Moving to seperate structs means that the compiler can check to make sure the right data is being passed into the right functions.

*What's the downside?* Creating a new `AppendRequest` without the use of a helper function can look a little gross: `ClientRequest::AppendRequest(AppendRequest { ... })`

But a helper can mask this grossness:

    impl<T> ClientRequest<T> {
        /// Returns (term, success)
        pub fn index_range(start: u64, end: u64) -> ClientRequest<T> {
            ClientRequest::IndexRange(IndexRange {
                start_index: start,
                end_index: end,
            })
        }

        /// Returns (term, voteGranted)
        pub fn append_request(prev_log_index: u64, prev_log_term: T, entries: Vec<T>) -> ClientRequest<T> {
            ClientRequest::AppendRequest(AppendRequest {
                prev_log_index: prev_log_index,
                prev_log_term: prev_log_term,
                entries: entries
            })
        }
    }

### Interfacing

A `RaftNode` now is spawned via the following function

    pub fn start (id: u64, nodes: Vec<(u64, SocketAddr)>) ->
    (Sender<ClientRequest<T>>, Receiver<Result<Vec<T>, String>>)

Well isn't that a long function signature? Basically, once you spawn a RaftNode it gets *immediately* moved into it's own thread and you are given a pair of channels to talk to it over. You send `ClientRequest`s and get back the rather familiar `Result` type. In the future it might be beneficial to expose something other than channels, but currently I think that's the best choice.

> I'm still wrangling ownership and borrowing, as I think many Rust users are, and some of my design choices are specifically because I wanted to avoid friction for now.

Since I've not been a user of any of the other Raft implementations out there (other than a bit of playing with [`etcd`](https://github.com/coreos/etcd)) I don't have much of a basis to go off what's a "nice" interface. My goal is to remove as much of the complexities and management of the library from the user as possible. Ideally once they start their `RaftNode`s they'll only need to worry about sending requests and getting responses.

### Event Loop

I took a look at [`mio`](https://github.com/carllerche/mio) which looks fantastic, however for the time being I'm still just doing an infinite `loop` as I'd like to keep dependencies *down* until Rust stabilizes a bit more. In the future using some sort of evented system would definitely be ideal.

## Experience

### Decoding Socket Data

I had all sorts of fun implementing the following code in the loop's main `tick()` function:

    match self.socket.recv_from(&mut read_buffer) {
        Ok((num_read, source)) => { // Something on the socket.
            // This is possibly an RPC from another node. Try to parse it out
            // and determine what to do based on it's variant.
            let data = str::from_utf8(&mut read_buffer[.. num_read])
                .unwrap();
            if let Ok(rpc) = json::decode::<RemoteProcedureCall<T>>(data) {
                match rpc {
                    RemoteProcedureCall::RequestVote(call) =>
                        self.handle_request_vote(call, source),
                    RemoteProcedureCall::AppendEntries(call) =>
                        self.handle_append_entries(call, source),
                }
            } else if let Ok(rpr) = json::decode::<RemoteProcedureResponse>(data) {
                match rpr {
                    RemoteProcedureResponse::Accepted { .. } =>
                        self.handle_accepted(rpr, source),
                    RemoteProcedureResponse::Rejected { .. } =>
                        self.handle_rejected(rpr, source),
                }
            }
        },
        Err(_) => (),                 // Nothing on the socket.
    }

This was the first time I used `if let` and it was very useful for destructuring in control flow. I'm looking forward to using `while let` soon.

*What does that code do... exactly?* When we recieve data from the network, it's either going to be a `RemoteProcedureCall`, a `RemoteProcedureResponse`, or something else entirely. Currently, I only account for the valid cases, the third case is outright ignored.

### Dealing with the State (Machine)

I read [this gist](https://gist.github.com/bvssvni/8970459) with great interest, however I've yet to determine how to go about implementing a truly type-safe state machine for Raft right now. I'd like to do this in the future, and I'd be thrilled if someone could help with advice, mentorship, or pull requests on how to accomplish this.

Currently, all of the data event handlers look roughly like this:

    fn handle_append_request(&mut self, request: AppendRequest<T>) {
        match self.state {
            Leader(ref state) => {
                unimplemented!();
            },
            Follower => {
                unimplemented!();
            },
            Candidate => {
                unimplemented!();
            },
        }
    }

### Dealing with Non-Pollables

One thing I noticed while working with Rust's `UdpSocket` imeplementation is there is no way to `poll()` the socket to see if there is data, so any time the socket is checked you *must* handle the data immediately. I'm currently avoiding having FIFO queues for the various data but that might end up being a requirement.

For those wondering, you can make a socket non-blocking by using this:

    let mut socket = UdpSocket::bind(own_socket_addr)
        .unwrap();
    socket.set_read_timeout(Some(0));

## Thoughts

Working with Rust has been **really fun**. *(Except when there is a breaking change which cascades through libraries and means you lose productivity.)*

**`match` expressions** are incredible things. If you haven't played around with Rust yet, they're so much more than a `switch` statement in your run of the mill language.

**API design** in Rust is very versatile and interesting. The strong typing and ownership system encourage you to work with data in sane and creative ways.

**Understanding your code** is emphasized in Rust far more than a language like Javascript. Understanding where your borrows come from, what lifetimes are applicable, etc are all valuable to you.

**Smart data structures and dumb code are better than vice versa...** and I think that Rust really helps with that.

## Explore and Help!

> https://github.com/Hoverbear/raft

Would you like to explore, give feedback, or contribute? Please do! Publicly you can just make an issue on Github, or privately just shoot me an email. (I'm *sure* you can find it on Github or here...)

**Discussion of this post is on [Reddit](https://www.reddit.com/r/rust/comments/2ux7xo/raft_experiences_part_1_and_repo_made_public/).**
