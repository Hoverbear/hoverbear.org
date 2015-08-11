---
layout: post
title: "Raft: A First Prototype"
author: "Andrew Hobden"
tags:
 - Raft
 - Rust
 - CSC466
 - CSC462
---

As you may have [previously](/2015/02/05/raft-update-1/) [read](/2015/02/18/raft-update-2/), I've been working on implementing the [Raft Distributed Consensus Algorithm](https://raftconsensus.github.io/) in [Rust](http://rust-lang.org/) for my classes (and fun!).

## Current Status ##

I'm proud to say I have the first *(fragile)* prototype of the library working *(most of the time)* as I type this. But with that said, the work has only really just begun.

Currently:

* **Elections:** *Works (most of the time)!*
  + There are corner cases where two nodes will contend for votes and occasionally lock up. I haven't managed to track this down yet.
* **Replicating Logs:** *Works, but isn't ideal!*
  + As I wrote about in my [last article](/2015/02/18/raft-update-2/) the current scheme isn't very intelligent.
  + [This issue](https://github.com/Hoverbear/raft/issues/4) is tracking possible improvements.
* **Handling Commits**: *Works!*
* **Interfacing with Consumers:** *Works, but needs more love!*
  + The API simply isn't very nice. Since I haven't gotten around to actually **using** Raft for anything serious I don't have a great idea about the desired interface.
* **Safety:** *Sort of!*
  + There is (predictably) no `unsafe` code in Raft.
  + There are several `.unwrap()` statements in places were, for now, I just want the code to panic.
  + Overflows aren't handled gracefully.
* **Efficiency:** *Needs love!*
* **Testing::** *In progress!*
* **Tooling:** *Rocks!*
  + [Travis CI Builds](https://travis-ci.org/Hoverbear/raft)
  + [Generated Docs](https://hoverbear.github.io/raft/raft/index.html)

## Architecture So Far

{<1>}![RaftNode Architecture](/content/images/2015/02/raft.png)

Each `RaftNode` runs on it's own thread alongside of the consuming program. The consumer program communicates along channels, sending `ClientRequest<T>` and recieving (at the moment) `io::Result<T>`.

A `RaftNode` talks to other `RaftNode`s via `UdpSocket`s using `RemoteProcedureCall<T>` and `RemoteProcedureResponse` messages.

> Note: I'm going to avoid talking about things I have already talked about in previous writings.

### Current Dependencies

With Rust still pre-beta, and my deadline for this prototype short, I wanted to reduce the number of dependencies to a minimum to avoid deadlocking. Please keep this in mind as you read forward as it was a primary consideration for some functionality like RPC.

* [`std`](http://doc.rust-lang.org/std/index.html) - The stdlib.
* [`rustc-serialize`](https://github.com/rust-lang/rustc-serialize) - Generic serialization/deserialization support.
* [`uuid`](https://github.com/rust-lang/uuid) - Unique Universal Identifiers.
* [`rand`](https://github.com/rust-lang/rand) - Random number generators.
* [`log`](https://github.com/rust-lang/log) - Configurable logging.
* [`env_logger`](https://github.com/rust-lang/log) - For `log`.

### States

Nodes can either be:

* A `Follower`, which replicates `AppendEntries` requests and votes for it's leader.
  + Stores a log of it's recent requests of the `Leader` on behalf of the consumer.
* A `Leader`, which leads the cluster by serving incoming requests, ensuring data is replicated, and issuing heartbeats.
  + Stores `match_index` and `next_index` which are both `Vec<u64>` and specified by the Raft paper.
* A `Candidate`, which campaigns in an election and may become a `Leader` (if it gets enough votes) or a `Follower`, if it hears from a `Leader`.
  + Stores a `Vec<Transcation>` to keep track of it's `RequestVote` requests.

The resulting enum looks like:

    #[derive(PartialEq, Eq, Clone)]
    pub enum NodeState {
        Follower(VecDeque<Transaction>),
        Leader(LeaderState),
        Candidate(Vec<Transaction>),
    }

These variants all store their one specific data needed for *only* their operation. Changing between state clears all of the data.

### Transactions

`Transaction`s are used to track the state of a variety of things in the library. They look like this:

    #[derive(PartialEq, Eq, Clone)]
    pub struct Transaction {
        pub uuid: Uuid,
        pub state: TransactionState,
    }
    #[derive(PartialEq, Eq, Copy, Clone)]
    pub enum TransactionState {
        Polling,
        Accepted,
        Rejected,
    }

The idea is that when a `RemoteProcedureRequest` is made it generates a UUID which the `RaftNode` (particularly it's `node.state`) stores and uses to verify and identify responses.

In the case of `AppendEntries` there is no need for the `Leader(_)` to track UUIDs. They are mostly used for `Candidate(_)` elections and for the `Follower(_)` when it makes a request of the leader.

I'm not entirely happy with this approach, and I think that in the future moving to some form of RPC approach like [Cap'n Proto](http://www.hoverbear.org/2015/02/12/capn-proto-in-rust/) would be safer and faster.

> Moving to Cap'n Proto might serve two additional purposes: Increased compatability with other implementations, and providing examples (which are currently lacking for Rust!)

### The Tick

Currently, most of the work done by `tick()` which runs a loop.

	loop { raft_node.tick(); }

Now you're probably thinking "Oh gosh why?" and I **totally** agree with you. Ideally, we would use something like `epoll`. However, I wanted to simulate an event loop and hopefully move to [`mio`](https://github.com/carllerche/mio) soon, but it's undergoing a [reform](https://github.com/carllerche/mio/pull/127) so I'm holding off on that for a bit, there is plenty more to do!

If you have any advice on this, let me know [here](https://github.com/Hoverbear/raft/issues/6).

### Main Events

There are three main events which can occur:

* **The socket has data:** Parse the data into a `RemoteProcedureCall` or a `RemoteProcedureResponse` and handles it appropriately.
* **The timer has fired:** (Re)Start an election or heartbeat.
* **The channel has data:** Act on the clients command if there is a known leader.

> Gotcha: Only the `Leader(_)` or a `Follower(_)` (with a known leader) will retrieve from a channel for now.

### Logging

I just started migrating over to the **fantastic** [`log`](https://github.com/rust-lang/log) crate, and I just love it. It provides numerous macros for logging levels like `debug!()`, `info!()`, `log!()`.

Using it, you end up with something like this:

    if let Ok(rpc) = json::decode::<RemoteProcedureCall<T>>(data) {
        debug!("ID {}: FROM {:?} RECIEVED {:?}", self.own_id, source, rpc);
          // ..
        }

And this:

    match checks.iter().all(|&x| x) {
        true  => {
            self.persistent_state.set_voted_for(Some(source_id)).unwrap();
            self.reset_timer();
            info!("ID {}:F: TO {} ACCEPT request_vote", self.own_id, source_id);
            RemoteProcedureResponse::accept(call.uuid, current_term,
                last_index, self.volatile_state.commit_index)
        },

And the user is able to toggle directives at runtime, which is awesome! So set the logging level while testing a crate you can use:

    RUST_LOG=raft=debug cargo test -- --nocapture

Or use the same environment variable at runtime. You can even specifiy different log levels per crate. It's kind of neat to use a wildcard like `RUST_LOG=debug` with cargo because you actually see a considerable amount of compiler output.

Here's what the test output looks like with the highest level of logging:

    running 1 test
    INFO:raft: ID 2: HANDLE timer
    DEBUG:raft: ID 2: FOLLOWER -> CANDIDATE: Term 0
    DEBUG:raft: Node 2 timer RESET
    DEBUG:raft: Node 2 timer RESET
    DEBUG:raft: ID 2: SEND RequestVote(RequestVote { term: 1, candidate_id: 2, last_log_index: 0, last_log_term: 0, uuid: Uuid { bytes: [10, 1, 60, 118, 191, 114, 66, 35, 139, 241, 26, 177, 159, 117, 104, 222] } })
    DEBUG:raft: ID 2: SEND RequestVote(RequestVote { term: 1, candidate_id: 2, last_log_index: 0, last_log_term: 0, uuid: Uuid { bytes: [175, 43, 94, 204, 10, 194, 72, 149, 171, 80, 0, 233, 192, 112, 124, 210] } })
    DEBUG:raft: Node 2 timer RESET
    DEBUG:raft: ID 0: FROM SocketAddr { ip: Ipv4Addr(127, 0, 0, 1), port: 11112 } RECIEVED RequestVote(RequestVote { term: 1, candidate_id: 2, last_log_index: 0, last_log_term: 0, uuid: Uuid { bytes: [10, 1, 60, 118, 191, 114, 66, 35, 139, 241, 26, 177, 159, 117, 104, 222] } })
    DEBUG:raft: ID 1: FROM SocketAddr { ip: Ipv4Addr(127, 0, 0, 1), port: 11112 } RECIEVED RequestVote(RequestVote { term: 1, candidate_id: 2, last_log_index: 0, last_log_term: 0, uuid: Uuid { bytes: [175, 43, 94, 204, 10, 194, 72, 149, 171, 80, 0, 233, 192, 112, 124, 210] } })
    INFO:raft: ID 0: FROM 2 HANDLE request_vote
    INFO:raft: ID 1: FROM 2 HANDLE request_vote
    DEBUG:raft: Node 0 timer RESET
    INFO:raft: ID 0:F: TO 2 ACCEPT request_vote
    DEBUG:raft: Node 1 timer RESET
    DEBUG:raft: ID 0: TO SocketAddr { ip: Ipv4Addr(127, 0, 0, 1), port: 11112 } RESPONDS Accepted(Accepted { uuid: Uuid { bytes: [10, 1, 60, 118, 191, 114, 66, 35, 139, 241, 26, 177, 159, 117, 104, 222] }, term: 0, match_index: 0, next_index: 0 })
    INFO:raft: ID 1:F: TO 2 ACCEPT request_vote
    DEBUG:raft: ID 0: RESPOND Accepted(Accepted { uuid: Uuid { bytes: [10, 1, 60, 118, 191, 114, 66, 35, 139, 241, 26, 177, 159, 117, 104, 222] }, term: 0, match_index: 0, next_index: 0 })
    DEBUG:raft: ID 1: TO SocketAddr { ip: Ipv4Addr(127, 0, 0, 1), port: 11112 } RESPONDS Accepted(Accepted { uuid: Uuid { bytes: [175, 43, 94, 204, 10, 194, 72, 149, 171, 80, 0, 233, 192, 112, 124, 210] }, term: 0, match_index: 0, next_index: 0 })
    DEBUG:raft: ID 1: RESPOND Accepted(Accepted { uuid: Uuid { bytes: [175, 43, 94, 204, 10, 194, 72, 149, 171, 80, 0, 233, 192, 112, 124, 210] }, term: 0, match_index: 0, next_index: 0 })
    DEBUG:raft: ID 2: FROM SocketAddr { ip: Ipv4Addr(127, 0, 0, 1), port: 11110 } RECIEVED Accepted(Accepted { uuid: Uuid { bytes: [10, 1, 60, 118, 191, 114, 66, 35, 139, 241, 26, 177, 159, 117, 104, 222] }, term: 0, match_index: 0, next_index: 0 })
    INFO:raft: ID 2: FROM 0 HANDLE accepted
    DEBUG:raft: ID 2:C: FROM 0 MATCHED
    // ...

On the normal level:

         Running target/lib-800267e679b6e5c6

    running 1 test
    test basic_test ... ok

    test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured


### Dealing with Failures

Most failure modes are defined by the Raft paper, and I'm attempting to implement them the best I can. Currently there is an `unimplemented!()` section of the code I'm still working on figuring out the correct course of action.

## The 'Demo'

> As I mentioned, the interface with the consuming library is in need of rework, so it's not very clean.

Here is the current most basic possible functioning hunk of code to fire up a cluster:

    let nodes = vec![
        (0, SocketAddr { ip: Ipv4Addr(127, 0, 0, 1), port: 11110 }),
        (1, SocketAddr { ip: Ipv4Addr(127, 0, 0, 1), port: 11111 }),
        (2, SocketAddr { ip: Ipv4Addr(127, 0, 0, 1), port: 11112 }),
    ];
    // Create the nodes.
    let (log_0_sender, log_0_reciever) = RaftNode::<String>::start(
        0,
        nodes.clone(),
        Path::new("/tmp/test0")
    );
    let (log_1_sender, log_1_reciever) = RaftNode::<String>::start(
        1,
        nodes.clone(),
        Path::new("/tmp/test1")
    );
    let (log_2_sender, log_2_reciever) = RaftNode::<String>::start(
        2,
        nodes.clone(),
        Path::new("/tmp/test2")
    );

Here is the current code to make an append request and check that it at least got to the leader:

    // Make a test send to that port.
    let test_command = ClientRequest::AppendRequest(AppendRequest {
        entries: vec!["foo".to_string()],
        prev_log_index: 0,
        prev_log_term: 0,
    });
    log_0_sender.send(test_command.clone()).unwrap();
    // Get the result.
    wait_a_second();
    let event = log_0_reciever.try_recv()
        .ok().expect("Didn't recieve in a reasonable time.");
    assert!(event.is_ok()); // Workaround until we build a proper stream.

Here is the how to check an for items in an index, notice the graceful failing of "overasking":

    // Test Index.
    let test_index = ClientRequest::IndexRange(IndexRange {
            start_index: 0,
            end_index: 5,
    });
    log_0_sender.send(test_index.clone()).unwrap();
    wait_a_second();
    let result = log_0_reciever.try_recv()
        .ok().expect("Didn't recieve in a reasonable time.").unwrap();
    // We don't know what the term will be.
    assert_eq!(result, vec![(result[0].0, "foo".to_string())]);

## Further Work

A **lot** of further work is needed to make this library ready for action. Here is a brief summary:

* [Tame the Tick!](https://github.com/Hoverbear/raft/issues/6)
* [Use a Better Log!](https://github.com/Hoverbear/raft/issues/4)
* Use a more established RPC paradigm like Cap'n Proto.
* Improve consumer interface. (Possibly through facade functions?)
* Membership Changes
* Snapshotting

## Explore and Help!

> https://github.com/Hoverbear/raft

Would you like to explore, give feedback, or contribute? Please do! Publicly you can just make an issue on Github, or privately just shoot me an email. (I'm sure you can find it on Github or here...)

**Discussion of this post is on [Reddit](https://www.reddit.com/r/rust/comments/2wyq2e/raft_a_first_prototype/).**
