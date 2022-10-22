+++
title = "Raft So Far"
aliases = ["2015/01/25/raft-so-far/"]
template = "blog/single.html"
[taxonomies]
tags = [
  "Raft",
  "Rust",
]
+++

I've been working quite a bit on my Raft implementation over the last few days and I must say it's been quite a pleasure to work in Rust, which recently released it's 1.0.0-alpha.

It takes the work out of needing to serialize and deserialize data, it enforces data safety, and it's type checking is incredible. I'm very quickly able to make a change, build it, fix the errors the compiler catches for me, and build again, then test. So far the only times my tests have failed after a successful build was when I was accidently disgarding one of my channels.

<!-- more -->

## Client Interface

Currently, the design of my implementation is meant to be as simple as I can possibly make it. Once a `RaftNode` is created (`RaftNode::new()`) and spun up (`node.spinup()`) the client program will recieve a channel which to communicate on with the node.

I wanted to remove the complexity of having to make network requests outside of the Node. If you're participating in a Raft cluster you don't want to have to think about it, you just want to read logs and append logs. Raft's goal is to implement a replicated log, or state machine.

	fn spinup(self) -> (Sender<ClientRequest<T>>,
    					Receiver<ClientResponse<T>>)
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

    enum ClientResponse<T> {
        Accepted {
            entries: Vec<T>,
            last_index: u64,
        },
        Rejected {
            reason: String,
        },
    }

Right now most of the data types I'm using are compound data enums, allowing for strongly typed, encapsulated data that is easy to work with via `match` statements.

I am not sure if this is the *right* way to go about things, and I think that there can be some improvement, but this method of requests across a channel are, as far as I can tell, the idomatic way to communicate with a thread in Rust.

One cool thing about this approach is the log entries themselves can be basically anything the programmer desires as long as it can be serialized and deserialized. I'm mostly using `String`s for testing.

## Remote Procedure Calls

Inside of the `RaftNode`'s thread it binds on a UDP socket and listens for `RemoteProcedureCall` data. These requests are encoded and decoded through the `rustc-serialize` crato, but in the future `serde` will probably replace it.

A `RemoteProcedureCall` looks almost identical to those dictated in the Raft paper:

    #[derive(RustcEncodable, RustcDecodable, Debug, Clone)]
    pub enum RemoteProcedureCall<T> {
        AppendEntries {
            term: u64,
            leader_id: u64,
            prev_log_index: u64,
            prev_log_term: T,
            entries: Vec<T>,
            leader_commit: u64,
        },
        RequestVote {
            term: u64,
            candidate_id: u64,
            last_log_index: u64,
            last_log_term: u64,
        },
    }

    #[derive(RustcEncodable, RustcDecodable, Debug, Copy)]
    pub enum RemoteProcedureResponse {
        VoteAccepted { term: u64 },
        VoteRejected { term: u64, current_leader: u64 },
        EntriesAccepted { term: u64 },
        EntriesRejected { term: u64 },
    }

I'm not sure if the way I'm approaching the `RemoteProcedureResponse` is necessarily the right way to go about things. I think it might be better to model it after `ClientResponse`.

## Progress

Most of the work done so far is on scaffolding, and determining interfaces. I have two nodes running locally successfully passing `ClientRequest`s into one node, them communicating with a `RemoteProcedureCall` and a `ClientResponse` being emitted at the other node.

I've been spending a lot of time documenting my thoughts and ideas in the code as I write it, `// TODO:` is sprinkled throughout.

## Repository

Currently the state of the code is such that I don't feel right releasing it to the public, once I have some bearance of functionality in the crate I'll be releasing it under the MIT license.

If you're interested in helping out with this implementation please let me know. I'd be happy to include you in the private Github repository. I am currently working on it as part of a course project, but can accept contributions so long as I maintain a log of my work.

**Discussion of this post was on [Reddit](https://www.reddit.com/r/rust/comments/2tncd1/raft_so_far_first_steps_into_implementation_in/).**
