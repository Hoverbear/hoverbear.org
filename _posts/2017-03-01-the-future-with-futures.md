---
layout: post
title: "The Future with Futures"

image: /assets/images/2017/03/space.jpg
image-credit: "NASA"

tags:
  - Rust
  - Tutorials

# published: false
---

Recently there has been a lot of progress in the Rust language towards a robust asyncronous stack. In this article we'll take a look at what these things are, take a tour of what's available, play with some examples, and talk about how the pieces fit together.

We'll get started with the `futures` crate to start, move on to `futures_cpupool`, and then eventually to `tokio`. We will assume you have some knowledge of programming, and have at least thought about trying Rust before.

## What are Futures and Async?

When writing code to do some action which may take some time, such as requesting a resource from a remote host, it is not always desirable to block further execution of our program. This is particularly true in the case where we are writing a web server, or performing a large number of complex calculations.

One way of handling this is to spawn threads and discretely slice up tasks to be distributed across threads. This is not always as convienent or as easy as it may sound. Suddenly we are forced to figure out how tasks are best split, how to allocate resources, to program against race conditions, and manage interthread communication.

As a community we've learnt some techniques over the years, such as CPU pools which allow a number of threads to cooperate on a task, and 'future' values which resolve to their intended value after they are finished some computation. These provide us useful and powerful tools that makes it easier, safer, and more fun to write such code.

If you've ever developed in Javascript you may already be familiar with asyncronous programming and the idea of Promises. Futures in Rust are very similar to this, but we're provided more control and more responsibility. With this comes greater power.

## How We Got Here

Much of this async work has been in development since green threads were removed from Rust around the 0.7 release. There have been several projects related to futures and async since, their influence can be felt by what we have now and what is on the horizon.

Much of the async story today is founded on the ideas and lessons learned from `std`'s green threads, [`mio`](https://github.com/carllerche/mio), [`coroutine`](https://github.com/rustcc/coroutine-rs), and [`rotor`](https://github.com/tailhook/rotor). `mio` in particular is a foundation of nearly the entire async area of Rust. If you have interest in seeing high quality systems code I highly reccomend paying some attention to this project.

Today, [`tokio`](https://tokio.rs/) and [`futures`](https://github.com/alexcrichton/futures-rs) are the focus of much community effort. Recently [Tokio accounced its first release](https://tokio.rs/blog/tokio-0-1/), while futures have been relatively stable for a couple months. This has spurned a large amount of development within the community to support and leverage these new capabilities.

## Getting Started

The `futures` crate offers a number of structures and abstractions to *enable* building asyncronous code. By itself it's quite simple, and through its clever design it is fundamentally a zero cost abstraction. This is an important thing to keep in mind as we work through our examples: Writing code with futures should have no performance overhead over code without.

When compiled futures [boil down to actual state machines](https://aturon.github.io/blog/2016/08/11/futures/) while still allowing us to write our code in a relatively familiar 'callback style' pattern. If you've already been using Rust then working with Futures will feel very similar to how iterators feel.

One of the things we'll commonly do in this section is "sleep a little bit" on a thread to simulate some asyncronous action. In order to do this let's create a little function:

```rust
extern crate rand;

use std::thread;
use std::time::Duration;
use rand::distributions::{Range, IndependentSample};

// This function sleeps for a bit, then returns how long it slept.
pub fn sleep_a_little_bit() -> u64 {
    let mut generator = rand::thread_rng();
    let possibilities = Range::new(0, 1000);

    let choice = possibilities.ind_sample(&mut generator);

    let a_little_bit = Duration::from_millis(choice);
    thread::sleep(a_little_bit);
    choice
}
```

Now that we've got that established we can use it in our first future. We'll use a `oneshot` to delegate a task to another thread, then pick it up back in the main thread. A oneshot is essentially a single use channel, something can be sent from the sender to the receiver, then the channel is closed.

```rust
extern crate futures;
extern crate fun_with_futures;

use std::thread;
use futures::Future;
use futures::sync::oneshot;

use fun_with_futures::sleep_a_little_bit;

fn main() {
    // This is a simple future built into the crate which feel sort of like
    // one-time channels. You get a (sender, receiver) when you invoke them.
    // Sending a value consumes that side of the channel, leaving only the reciever.
    let (tx, rx) = oneshot::channel();

    // We can spawn a thread to simulate an action that takes time, like a web
    // request. In this case it's just sleeping for a random time.
    thread::spawn(move || {
        println!("--> START");

        let waited_for = sleep_a_little_bit();
        println!("--- WAITED {}", waited_for);
        // This consumes the sender, we can't use it afterwards.
        tx.complete(waited_for);

        println!("<-- END");
    });

    // Now we can wait for it to finish
    let result = rx.wait()
        .unwrap();

    // This value will be the same as the previous "WAITED" output.
    println!("{}", result);
}
```

If we run this example we'll see something like:

```
--> START
--- WAITED 542
<-- END
542
```

The output is exactly what we might expect if we were doing this via the `std` channels. The code looks similar as well. At this point we're barely using Futures at all, so it shouldn't be a huge surprise that there is nothing surprising happening here. Futures start to come into their own during much more complicated tasks.

Next, let's look at how we can work with a set of futures. In this example we'll spawn a number of threads, have them do some long running task, and then collect all of the results into a vector.

```rust
extern crate futures;
extern crate fun_with_futures;

use std::thread;
use futures::Future;
use futures::future::join_all;

use fun_with_futures::sleep_a_little_bit;

const NUM_OF_TASKS: usize = 10;

fn main() {
    // We'll create a set to add a bunch of recievers to.
    let mut rx_set = Vec::new();

    // Next we'll spawn up a bunch of threads doing 'something' for a bit then sending a value.
    for index in 0..NUM_OF_TASKS {
        // Here we create a future, this is a `oneshot` value which is consumed after use.
        let (tx, rx) = futures::oneshot();
        // Add the reciever to the vector we created earlier so we can collect on it.
        rx_set.push(rx);

        // Spawning up a thread means things won't be executed sequentially, so this will actually
        // behave like an asyncronous value, so we can actually see how they work.
        thread::spawn(move || {
            println!("{} --> START", index);

            let waited_for = sleep_a_little_bit();
            println!("{} --- WAITED {}", index, waited_for);

            // Here we send back the index (and consume the sender).
            tx.complete(index);

            println!("{} <-- END", index);
        });
    }

    // `join_all` lets us join together the set of futures.
    let result = join_all(rx_set)
        // Block until they all are resolved.
        .wait()
        // Check they all came out in the right order.
        .map(|values|
            values.iter()
                .enumerate()
                .all(|(index, &value)| index == value))
        // We'll be lazy and just unwrap the result.
        .unwrap();

    println!("Job is done. Values returned in order: {}", result);
}
```

The `map` call behaves just like the `map` of an `Option<T>` or a `Result<T,E>`. It transforms some `Future<T>` into some `Future<U>`.  Running this example in output similar to the following:

```
0 --> START
1 --> START
3 --> START
2 --> START
4 --> START
5 --> START
6 --> START
7 --> START
8 --> START
9 --> START
4 --- WAITED 124
4 <-- END
1 --- WAITED 130
1 <-- END
0 --- WAITED 174
0 <-- END
2 --- WAITED 268
2 <-- END
6 --- WAITED 445
6 <-- END
3 --- WAITED 467
3 <-- END
9 --- WAITED 690
9 <-- END
8 --- WAITED 694
8 <-- END
5 --- WAITED 743
5 <-- END
7 --- WAITED 802
7 <-- END
Job is done. Values returned in order: true
```

In this example we can observe that all of the futures started, waited various times, then finished. They did not finish in order, but the resulting vector did come out in the correct order. Again, this result is not entirely surprising and we could have done something very similar with `std`'s channels.

> Remember, futures are a basic building block, not a batteries included solution. They are intended to be built on top of.

We'll cover one more example which will feel fairly familiar to people who have used the channels from `std`, then we'll start doing more interesting stuff.

The next primitive from `futures` we'll use is the [`futures::sync::mpsc::channel`](https://docs.rs/futures/0.1.10/futures/sync/mpsc/fn.channel.html) which behaves similar to the [`std::sync::mpsc::channel`](https://doc.rust-lang.org/std/sync/mpsc/fn.channel.html). We'll build a channel then pass off the sender `tx` to another thread, then we'll fire a series of messages along the channel. The `rx` side of the channel can then be used similarly to an `Iterator`.

```rust
extern crate futures;
extern crate fun_with_futures;

use std::thread;
use futures::future::{Future, ok};
use futures::stream::Stream;
use futures::sync::mpsc;
use futures::Sink;

use fun_with_futures::sleep_a_little_bit;

const BUFFER_SIZE: usize = 10;

fn main() {
    // A channel represents a stream and will yield a series of futures.

    // We're using a bounded channel here with a limited size.
    let (mut tx, rx) = mpsc::channel(BUFFER_SIZE);

    thread::spawn(move || {
        println!("--> START THREAD");
        // We'll have the stream produce a series of values.
        for _ in 0..10 {

            let waited_for = sleep_a_little_bit();
            println!("--- THREAD WAITED {}", waited_for);

            // When we `send()` a value it consumes the sender. Returning
            // a 'new' sender which we have to handle. In this case we just
            // re-assign.
            match tx.send(waited_for).wait() {
                // Why do we need to do this? This is how back pressure is implemented.
                // When the buffer is full `wait()` will block.
                Ok(new_tx) => tx = new_tx,
                Err(_) => panic!("Oh no!"),
            }

        }
        println!("<-- END THREAD");
        // Here the stream is dropped.
    });

    // We can `.fold()` like we would an iterator. In fact we can do many
    // things like we would an iterator.
    let sum = rx.fold(0, |acc, val| {
            // Notice when we run that this is happening after each item of
            // the stream resolves, like an iterator.
            println!("--- FOLDING {} INTO {}", val, acc);
            // `ok()` is a simple way to say "Yes this worked."
            // `err()` also exists.
            ok(acc + val)
        })
        .wait()
        .unwrap();
    println!("SUM {}", sum);
}
```

The output will be similar to the following:

```
--> START THREAD
--- THREAD WAITED 166
--- FOLDING 166 INTO 0
--- THREAD WAITED 554
--- FOLDING 554 INTO 166
--- THREAD WAITED 583
--- FOLDING 583 INTO 720
--- THREAD WAITED 175
--- FOLDING 175 INTO 1303
--- THREAD WAITED 136
--- FOLDING 136 INTO 1478
--- THREAD WAITED 155
--- FOLDING 155 INTO 1614
--- THREAD WAITED 90
--- FOLDING 90 INTO 1769
--- THREAD WAITED 986
--- FOLDING 986 INTO 1859
--- THREAD WAITED 830
--- FOLDING 830 INTO 2845
--- THREAD WAITED 21
<-- END THREAD
--- FOLDING 21 INTO 3675
SUM 3696
```

Now that we're familiar with these basic ideas we can move on to working with `futures_cpupool`.

## Dipping Our Toes Into the CPU Pool

Earlier we alluded to the idea of using futures with a CPU pool where we didn't have to manage which thread did which work, but in our examples so far we've still had to manually spin up threads. So let's fix that.

The [`futures_cpupool`](https://docs.rs/futures-cpupool/0.1.3/futures_cpupool/) crate offers us this functionality. Let's take a look at a basic example which does nearly the same thing as our second example above:

```rust
extern crate futures;
extern crate fun_with_futures;
extern crate futures_cpupool;

use futures::future::{Future, join_all};
use futures_cpupool::Builder;

use fun_with_futures::sleep_a_little_bit;

// Feel free to change me!
const NUM_OF_TASKS: usize = 10;

fn main() {
    // Creates a CpuPool with workers equal to the cores on the machine.
    let pool = Builder::new()
        .create();

    // Create a batch of futures.
    let futures = (0..NUM_OF_TASKS)
        // Tell the pool to run a closure.
        .map(|index| pool.spawn_fn(move || {

            println!("{} --> START", index);
            let waited_for = sleep_a_little_bit();
            println!("{} <-- WAITED {}", index, waited_for);

            // We need to return a result!
            // Why? Futures were implemented with I/O in mind!
            let result: Result<_, ()> = Ok(index);

            result
        })).collect::<Vec<_>>();

    // We wait on all the futures here and see if they came back in order.
    let result = join_all(futures)
        // Check they all came out in the right order.
        .map(|values|
            values.iter()
                .enumerate()
                .all(|(index, &value)| index == value))
        .wait()
        .unwrap();
    println!("Job is done. Values returned in order: {:?}", result)
}
```

This outputs something similar to the following:

```
0 --> START
1 --> START
2 --> START
3 --> START
4 --> START
5 --> START
6 --> START
7 --> START
0 <-- WAITED 37
8 --> START
2 <-- WAITED 86
9 --> START
3 <-- WAITED 110
6 <-- WAITED 326
9 <-- WAITED 458
4 <-- WAITED 568
5 <-- WAITED 748
7 <-- WAITED 757
1 <-- WAITED 794
8 <-- WAITED 838
Job is done. Values returned in order: true
```

This time we didn't need to manage threads or which thread does what. The pool just handled it for us. This is pretty handy. We can be rather arbitrary with what we do with the pool. For example different spawned tasks can return different types:

```rust
extern crate futures;
extern crate fun_with_futures;
extern crate futures_cpupool;

use futures::future::Future;
use futures_cpupool::Builder;

use fun_with_futures::sleep_a_little_bit;

fn main() {
    // Creates a CpuPool with workers equal to the cores on the machine.
    let pool = Builder::new()
        .create();

    // Note the two spawns return different types.
    let returns_string = pool.spawn_fn(move || {
        sleep_a_little_bit();
        // We need to return a result!
        let result: Result<_, ()> = Ok("First");

        result
    });

    let returns_integer = pool.spawn_fn(move || {
        sleep_a_little_bit();
        // We need to return a result!
        let result: Result<_, ()> = Ok(2);

        result
    });

    // Wait for the jobs to finish.
    let resulting_string = returns_string.wait()
        .unwrap();

    let resulting_integer = returns_integer.wait()
        .unwrap();
    
    println!("{}, {}", resulting_string, resulting_integer);
    // Returns `First, 2`
}
```

This means that we can create a CPU pool and delegate arbitrary tasks to it throughout the lifetime of our program. It may be that you want to create multiple pools to prevent starvation, for example a pool with 2 workers for network connections, and another with 2 workers for delayed jobs.

## Visiting Tokio's Core

The [`tokio`](https://tokio.rs/) project has been developed closely alongside of `futures` and the projects share many authors. The project has a number of crates intended for building asyncronous applications. In the `tokio-core` crate there are things like the main event loop, TCP handlers, and timeouts. Building on top of that are crates such as `tokio-proto` and `tokio-service` which build on top of these constructs.

We'll start with just `tokio-core` and doing a simple HTTP GET request. Note since we're not actually using a HTTP client we need to handle all the details ourselves. Here's what that looks like:

```rust
extern crate futures;
extern crate tokio_core;

use std::net::ToSocketAddrs;
use futures::future::Future;
use tokio_core::io::{read_to_end, write_all};
use tokio_core::reactor::Core;
use tokio_core::net::TcpStream;

const DOMAIN: &'static str = "google.com";
const PORT: u16 = 80;

fn main() {
    // Create the event loop that will drive this server.
    let mut core = Core::new().unwrap();
    let handle = core.handle();

    // Get a socket address from a domain name.
    let socket_addr = (DOMAIN, PORT).to_socket_addrs()
        .map(|iter| iter.collect::<Vec<_>>())
        .unwrap()[0];
    
    // Connect with a handle to the core event loop.
    let response = TcpStream::connect(&socket_addr, &handle)
        .and_then(|socket| {
            // Write a raw GET request onto the socket.
            write_all(socket, format!("\
                GET / HTTP/1.0\r\n\
                Host: {}\r\n\
                \r\n\
            ", DOMAIN))
        }).and_then(|(socket, _request)| {
            // Read the response into a buffer.
            read_to_end(socket, Vec::new())
        });

    // Fire the task off onto the event loop.
    let (_socket, data) = core.run(response).unwrap();

    // Parse the data and output it.
    println!("{}", String::from_utf8(data).unwrap());
}
```


This looks a bit different than what we've previously been doing with our futures. [`Core::new()`](https://docs.rs/tokio-core/0.1.4/tokio_core/reactor/struct.Core.html) is how we create an event loop, or 'Reactor', which we can get [`Handle`s](https://docs.rs/tokio-core/0.1.4/tokio_core/reactor/struct.Handle.html) which we use when issuing tasks such as `TcpStream::Connect`. You can learn more about the basics of the Reactor [here](https://tokio.rs/docs/getting-started/reactor/).

Working with the types provided by Tokio is slightly different than working with those provided by `std`, however many of the ideas and concepts are the same. Many of the changes are due to the differences between syncronous and asyncronous I/O.

Near the end of the example we have `core.run()` which is a way to fire off **one off** tasks and get a return value from them, similar to how we were using futures. Tokio also provides a `spawn()` and `spawn_fn()` functions which are executed in the background and must do their own handling of errors, making it ideal for tasks such as responding to new connections.

Let's play with `spawn_fn()` in our next example by making a simple server.

```rust
extern crate futures;
extern crate tokio_core;

use std::net::SocketAddr;
use futures::future::Future;
use futures::Stream;
use tokio_core::io::{read_to_end, write_all};
use tokio_core::reactor::Core;
use tokio_core::net::TcpListener;

const LISTEN_TO: &'static str = "0.0.0.0:8080";

fn main() {
    // Create the event loop that will drive this server.
    let mut core = Core::new().unwrap();
    let handle = core.handle();

    // Get a SocketAddr
    let socket: SocketAddr = LISTEN_TO.parse()
        .unwrap();
    
    // Start listening.
    let listener = TcpListener::bind(&socket, &handle)
        .unwrap();
    
    // For each incoming connection...
    let server = listener.incoming().for_each(|(stream, _client_addr)| {
        // Spawn the task on the reactor.
        handle.spawn_fn(|| {
            // Read until EOF
            read_to_end(stream, Vec::new())
                .and_then(|(socket, data)| {
                    // Write the recieved data.
                    write_all(socket, data)
                })
                // Errors have to be handled internally.
                .map(|_| ())
                .map_err(|_| ())
        });

        Ok(()) // keep accepting connections
    });

    // Run the reactor.
    core.run(server).unwrap();
}
// Throw some data at it with `echo "Test" | nc 127.0.0.1 8080`
```

Running `echo "Test" | nc 127.0.0.1 8080` in another terminal echos back the data sent. 

However, our example here isn't very useful, or idiomatic! For example, we can't use something like `telnet` or `curl` to interact with it. It's a start though. Let's do better.

We'll improve on our previous example by using a [`Codec`](https://docs.rs/tokio-core/0.1.4/tokio_core/io/trait.Codec.html). `Codec`s allow us to describe how to encode and decode the frames a `TcpStream` (or anything else that can be `framed()`). It asks us to define an `In` and an `Out` type as well as `encode()` and `decode()` functions.

Here's what our example with `EchoCodec` could look like:

```rust
extern crate futures;
extern crate tokio_core;

use std::net::SocketAddr;
use futures::future::Future;
use futures::Stream;
use std::io::Result;
use tokio_core::io::{Codec, EasyBuf, Io};
use tokio_core::reactor::Core;
use tokio_core::net::TcpListener;

const LISTEN_TO: &'static str = "0.0.0.0:8080";

// Codecs can have state, but this one doesn't.
struct EchoCodec;
impl Codec for EchoCodec {
    // Associated types which define the data taken/produced by the codec.
    type In = Vec<u8>;
    type Out = Vec<u8>;

    // Returns `Ok(Some(In))` if there is a frame, `Ok(None)` if it needs more data.
    fn decode(&mut self, buf: &mut EasyBuf) -> Result<Option<Self::In>> {
        // It's important to drain the buffer!
        let amount = buf.len();
        let data = buf.drain_to(amount);
        Ok(Some(data.as_slice().into()))
    }

    // Produces a frame.
    fn encode(&mut self, msg: Self::Out, buf: &mut Vec<u8>) -> Result<()> {
        buf.extend(msg);
        Ok(())
    }
}

fn main() {
    // Create the event loop that will drive this server.
    let mut core = Core::new().unwrap();
    let handle = core.handle();

    // Get a SocketAddr
    let socket: SocketAddr = LISTEN_TO.parse()
        .unwrap();
    
    // Start listening.
    let listener = TcpListener::bind(&socket, &handle)
        .unwrap();
    
    // For each incoming connection...
    let server = listener.incoming().for_each(|(stream, _client_addr)| {
        // Spawn the task on the reactor.
        handle.spawn_fn(|| {
            // Using our codec, split the in/out into frames.
            let (writer, reader) = stream.framed(EchoCodec).split();
            // Here we just sink any data recieved directly back into the socket.
            reader.forward(writer)
                // We need to handle errors internally.
                .map(|_| ())
                .map_err(|_| ())
        });

        Ok(()) // keep accepting connections
    });

    // Run the reactor.
    core.run(server).unwrap();
}
// Throw some data at it with `echo "Test" | nc 127.0.0.1 8080`
```

If you test this out you'll find the same behaviour as the previous example. With a little change we can even make it handle lines instead of entire messages, we'll borrow some code from Tokio's examples to do this:

```rust
// Codecs can have state, but this one doesn't.
struct EchoCodec;
impl Codec for EchoCodec {
    // Associated types which define the data taken/produced by the codec.
    type In = String;
    type Out = String;

    // Returns `Ok(Some(In))` if there is a frame, `Ok(None)` if it needs more data.
    fn decode(&mut self, buf: &mut EasyBuf) -> io::Result<Option<Self::In>> {
        match buf.as_slice().iter().position(|&b| b == b'\n') {
            Some(i) => {
                // Drain from the buffer (this is important!)
                let line = buf.drain_to(i);

                // Also remove the '\n'.
                buf.drain_to(1);

                // Turn this data into a UTF string and return it in a Frame.
                match str::from_utf8(line.as_slice()) {
                    Ok(s) => Ok(Some(s.to_string())),
                    Err(_) => Err(io::Error::new(io::ErrorKind::Other,
                                                "invalid UTF-8")),
                }
            },
            None => Ok(None),
        }
    }

    // Produces a frame.
    fn encode(&mut self, msg: Self::Out, buf: &mut Vec<u8>) -> io::Result<()> {
        buf.extend(msg.as_bytes());
        // Add the necessary newline.
        buf.push(b'\n');
        Ok(())
    }
}
```

Running this example you can connect with `nc 127.0.0.1 8080` and send some lines of text, then get them back. Notice how we didn't have to change the rest of the code at all in order to make this change? All we had to do was change the behaivor of the codec.

Now let's try making a codec that encodes and decodes HTTP 1.1 GET and POST requests made from `curl` that we can build on later:

```rust
enum ExampleRequest {
    Get { url: String },
    Post { url: String, content: String },
}

enum ExampleResponse {
    NotFound,
    Ok { content: String },
}

// Codecs can have state, but this one doesn't.
struct ExampleCodec;
impl Codec for ExampleCodec {
    // Associated types which define the data taken/produced by the codec.
    type In = ExampleRequest;
    type Out = ExampleResponse;

    // Returns `Ok(Some(In))` if there is a frame, `Ok(None)` if it needs more data.
    fn decode(&mut self, buf: &mut EasyBuf) -> io::Result<Option<Self::In>> {
        let content_so_far = String::from_utf8_lossy(buf.as_slice())
            .to_mut()
            .clone();

        // Request headers/content in HTTP 1.1 are split by double newline.
        match content_so_far.find("\r\n\r\n") {
            Some(i) => {
                // Drain from the buffer (this is important!)
                let mut headers = {
                    let tmp = buf.drain_to(i);
                    String::from_utf8_lossy(tmp.as_slice())
                        .to_mut()
                        .clone()
                };
                buf.drain_to(4); // Also remove the '\r\n\r\n'.

                // Get the method and drain.
                let method = headers.find(" ")
                    .map(|len| headers.drain(..len).collect::<String>());

                headers.drain(..1); // Get rid of the space.

                // Since the method was drained we can do it again to get the url.
                let url = headers.find(" ")
                    .map(|len| headers.drain(..len).collect::<String>())
                    .unwrap_or_default();

                // The content of a POST.
                let content = {
                    let remaining = buf.len();
                    let tmp = buf.drain_to(remaining);
                    String::from_utf8_lossy(tmp.as_slice())
                        .to_mut()
                        .clone()
                };

                match method {
                    Some(ref method) if method == "GET" => {
                        Ok(Some(ExampleRequest::Get { url: url }))
                    },
                    Some(ref method) if method == "POST" => {
                        Ok(Some(ExampleRequest::Post { url: url, content: content }))
                    },
                    _ => Err(io::Error::new(io::ErrorKind::Other, "invalid"))
                }
            },
            None => Ok(None),
        }
    }

    // Produces a frame.
    fn encode(&mut self, msg: Self::Out, buf: &mut Vec<u8>) -> io::Result<()> {
        match msg {
            ExampleResponse::NotFound => {
                buf.extend(b"HTTP/1.1 404 Not Found\r\n");
                buf.extend(b"Content-Length: 0\r\n");
                buf.extend(b"Connection: close\r\n");
            },
            ExampleResponse::Ok { content: v } =>  {
                buf.extend(b"HTTP/1.1 200 Ok\r\n");
                buf.extend(format!("Content-Length: {}\r\n", v.len()).as_bytes());
                buf.extend(b"Connection: close\r\n");
                buf.extend(b"\r\n");
                buf.extend(v.as_bytes());
            }
        }
        buf.extend(b"\r\n");
        Ok(())
    }
}
```

Let's be honest with ourselves here, this is very naive and is obviously incomplete! However it works for `curl -vvvv localhost:8080` and `curl -vvvv localhost:8080 --data hello`, and we got to learn a bit about how to use Tokio. So far so good! Let's build on it.

## Services and Protocols

`tokio-core` is, by definition, minimal. The `tokio-proto` and `tokio-service` crates build atop it to create common abstractions which we can use for various applications.

In this next example we'll build off our previous example of our naive HTTP server. Since the code chunks are starting to get significant let's work with isolated bits and we'll show the full example at the very end.

Our goal will be to build an ultra simple web server that responds to GET/POST requests. A POST to `/cats` with the data `meow` should return a `200` OK with the old value (if any) as the data, and any future GET to `/cats` should return `meow` as well until it is replaced. Our goal is simplicity and learning, not being robust or perfect.

First, we'll go ahead and define our protocol. We'll use a simple pipelined, non-streaming protocol. This code is quite generic and will generally look quite similar for different implementations. `tokio-proto` allow us to define the general style of our network. The [`tokio-proto` docs](https://docs.rs/tokio-proto/0.1.0/tokio_proto/) provide a good explanation of the differences.

```rust
use tokio_proto::pipeline::ServerProto;

// Like codecs, protocols can carry state too!
struct ExampleProto;
impl<T: Io + 'static> ServerProto<T> for ExampleProto {
    // These types must match the corresponding codec types:
    type Request = <ExampleCodec as Codec>::In;
    type Response = <ExampleCodec as Codec>::Out;

    /// A bit of boilerplate to hook in the codec:
    type Transport = Framed<T, ExampleCodec>;
    type BindTransport = Result<Self::Transport, io::Error>;
    fn bind_transport(&self, io: T) -> Self::BindTransport {
        Ok(io.framed(ExampleCodec))
    }
}
```

The service is less generic, and handles our little "database" inside of it. Due to the `Proto` and the `Codec` already handling most of the complicated bits, it's fairly straightforward. Services are reusable abstractions that operate over protocols.

Here's what our little HTTP example looks like:

```rust
// Surprise! Services can also carry state.
#[derive(Default)]
struct ExampleService {
    db: Arc<Mutex<HashMap<String, String>>>,
}

impl Service for ExampleService {
    // These types must match the corresponding protocol types:
    type Request = <ExampleCodec as Codec>::In;
    type Response = <ExampleCodec as Codec>::Out;

    // For non-streaming protocols, service errors are always io::Error
    type Error = io::Error;

    // The future for computing the response; box it for simplicity.
    type Future = BoxFuture<Self::Response, Self::Error>;

    // Produce a future for computing a response from a request.
    fn call(&self, req: Self::Request) -> Self::Future {
        println!("Request: {:?}", req);
        
        // Deref the database.
        let mut db = self.db.lock()
            .unwrap(); // This should only panic in extreme cirumstances.
        
        // Return the appropriate value.
        let res = match req {
            ExampleRequest::Get { url: url } => {
                match db.get(&url) {
                    Some(v) => ExampleResponse::Ok { content: v.clone() },
                    None => ExampleResponse::NotFound,
                }
            },
            ExampleRequest::Post { url: url, content: content } => {
                match db.insert(url, content) {
                    Some(v) => ExampleResponse::Ok { content: v },
                    None => ExampleResponse::Ok { content: "".into() },
                }
            }
        };
        println!("Database: {:?}", *db);

        // Return the result.
        future::finished(res).boxed()
    }
}
```

At this point we have all the pieces and just need to put them all together. This requires some changes to our `main()` function like so:

```rust
fn main() {
    // Get a SocketAddr
    let socket: SocketAddr = LISTEN_TO.parse()
        .unwrap();
    
    // Create a server with the protocol.
    let server = TcpServer::new(ExampleProto, socket);
    
    // Create a database instance to provide to spawned services.
    let db = Arc::new(Mutex::new(HashMap::new()));

    // Serve requests with our created service and a handle to the database.    
    server.serve(move || Ok(ExampleService { db: db.clone() }));
}
// Throw some data at it with `curl 127.0.0.1 8080/foo` and `curl 127.0.0.1 8080 --data bar`
```

Testing it out:

```bash
$ curl localhost:8080/bear           
$ curl localhost:8080/bear --data foo
$ curl localhost:8080/bear           
foo%                                                                                                                                                                   $ curl localhost:8080/bear --data bar
foo%
$ curl localhost:8080/bear
bar%
```

This is great, we've created a little network connected database with a "REST-ish" API. I hope this has taught you a bit about Futures and Tokio, and inspired you to play around further! 

> This post was supported in part through a time allocation from [Asquera](http://asquera.de/) and can be found [here](http://asquera.de/blog/2017-03-01/the-future-with-futures/). Thanks!


## Complete Tokio Example

```rust
extern crate futures;
extern crate tokio_core;
extern crate tokio_proto;
extern crate tokio_service;

use std::net::SocketAddr;
use futures::future::{self, BoxFuture, Future};
use std::sync::{Mutex, Arc};
use std::{io, str};
use std::collections::HashMap;
use tokio_core::io::{Codec, EasyBuf, Io, Framed};
use tokio_proto::TcpServer;
use tokio_proto::pipeline::ServerProto;
use tokio_service::Service;

const LISTEN_TO: &'static str = "0.0.0.0:8080";

#[derive(Debug)]
enum ExampleRequest {
    Get { url: String },
    Post { url: String, content: String },
}

enum ExampleResponse {
    NotFound,
    Ok { content: String },
}

// Codecs can have state, but this one doesn't.
struct ExampleCodec;
impl Codec for ExampleCodec {
    // Associated types which define the data taken/produced by the codec.
    type In = ExampleRequest;
    type Out = ExampleResponse;

    // Returns `Ok(Some(In))` if there is a frame, `Ok(None)` if it needs more data.
    fn decode(&mut self, buf: &mut EasyBuf) -> io::Result<Option<Self::In>> {
        let content_so_far = String::from_utf8_lossy(buf.as_slice())
            .to_mut()
            .clone();

        // Request headers/content in HTTP 1.1 are split by double newline.
        match content_so_far.find("\r\n\r\n") {
            Some(i) => {
                // Drain from the buffer (this is important!)
                let mut headers = {
                    let tmp = buf.drain_to(i);
                    String::from_utf8_lossy(tmp.as_slice())
                        .to_mut()
                        .clone()
                };
                buf.drain_to(4); // Also remove the '\r\n\r\n'.

                // Get the method and drain.
                let method = headers.find(" ")
                    .map(|len| headers.drain(..len).collect::<String>());

                headers.drain(..1); // Get rid of the space.

                // Since the method was drained we can do it again to get the url.
                let url = headers.find(" ")
                    .map(|len| headers.drain(..len).collect::<String>())
                    .unwrap_or_default();

                // The content of a POST.
                let content = {
                    let remaining = buf.len();
                    let tmp = buf.drain_to(remaining);
                    String::from_utf8_lossy(tmp.as_slice())
                        .to_mut()
                        .clone()
                };

                match method {
                    Some(ref method) if method == "GET" => {
                        Ok(Some(ExampleRequest::Get { url: url }))
                    },
                    Some(ref method) if method == "POST" => {
                        Ok(Some(ExampleRequest::Post { url: url, content: content }))
                    },
                    _ => Err(io::Error::new(io::ErrorKind::Other, "invalid"))
                }
            },
            None => Ok(None),
        }
    }

    // Produces a frame.
    fn encode(&mut self, msg: Self::Out, buf: &mut Vec<u8>) -> io::Result<()> {
        match msg {
            ExampleResponse::NotFound => {
                buf.extend(b"HTTP/1.1 404 Not Found\r\n");
                buf.extend(b"Content-Length: 0\r\n");
                buf.extend(b"Connection: close\r\n");
            },
            ExampleResponse::Ok { content: v } =>  {
                buf.extend(b"HTTP/1.1 200 Ok\r\n");
                buf.extend(format!("Content-Length: {}\r\n", v.len()).as_bytes());
                buf.extend(b"Connection: close\r\n");
                buf.extend(b"\r\n");
                buf.extend(v.as_bytes());
            }
        }
        buf.extend(b"\r\n");
        Ok(())
    }
}

// Like codecs, protocols can carry state too!
struct ExampleProto;
impl<T: Io + 'static> ServerProto<T> for ExampleProto {
    // These types must match the corresponding codec types:
    type Request = <ExampleCodec as Codec>::In;
    type Response = <ExampleCodec as Codec>::Out;

    /// A bit of boilerplate to hook in the codec:
    type Transport = Framed<T, ExampleCodec>;
    type BindTransport = Result<Self::Transport, io::Error>;
    fn bind_transport(&self, io: T) -> Self::BindTransport {
        Ok(io.framed(ExampleCodec))
    }
}

// Surprise! Services can also carry state.
#[derive(Default)]
struct ExampleService {
    db: Arc<Mutex<HashMap<String, String>>>,
}

impl Service for ExampleService {
    // These types must match the corresponding protocol types:
    type Request = <ExampleCodec as Codec>::In;
    type Response = <ExampleCodec as Codec>::Out;

    // For non-streaming protocols, service errors are always io::Error
    type Error = io::Error;

    // The future for computing the response; box it for simplicity.
    type Future = BoxFuture<Self::Response, Self::Error>;

    // Produce a future for computing a response from a request.
    fn call(&self, req: Self::Request) -> Self::Future {
        println!("Request: {:?}", req);
        
        // Deref the database.
        let mut db = self.db.lock()
            .unwrap(); // This should only panic in extreme cirumstances.
        
        // Return the appropriate value.
        let res = match req {
            ExampleRequest::Get { url: url } => {
                match db.get(&url) {
                    Some(v) => ExampleResponse::Ok { content: v.clone() },
                    None => ExampleResponse::NotFound,
                }
            },
            ExampleRequest::Post { url: url, content: content } => {
                match db.insert(url, content) {
                    Some(v) => ExampleResponse::Ok { content: v },
                    None => ExampleResponse::Ok { content: "".into() },
                }
            }
        };
        println!("Database: {:?}", *db);

        // Return the result.
        future::finished(res).boxed()
    }
}

fn main() {
    // Get a SocketAddr
    let socket: SocketAddr = LISTEN_TO.parse()
        .unwrap();
    
    // Create a server with the protocol.
    let server = TcpServer::new(ExampleProto, socket);

    // Create a database instance to provide to spawned services.
    let db = Arc::new(Mutex::new(HashMap::new()));

    // Serve requests with our created service and a handle to the database.    
    server.serve(move || Ok(ExampleService { db: db.clone() }));
}
// Throw some data at it with `curl 127.0.0.1 8080/foo` and `curl 127.0.0.1 8080 --data bar`
```

