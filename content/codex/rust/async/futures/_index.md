+++
title = "Futures"
description = "The world at 88 mph"
template = "blog/list.html"
sort_by = "weight"
weight = 0

[extra]
in_menu = true

[extra.image]
path =  "cover.jpg"
photographer = "Jason Leung"
source = "https://unsplash.com/photos/pSLIG2E_gaw"
+++

Rust Futures are broken down into two main traits:

* [`core::future::Future`](https://doc.rust-lang.org/std/future/trait.Future.html): Representing the minimal required implementation for an asyncronous task. This is, notably, part of `core` and always available, even without `alloc`.
* [`future::future::FutureExt`](https://docs.rs/futures/latest/futures/future/trait.FutureExt.html): A large collection of functionality you might expect or want as a programmer.

You'll also find a bunch of handy functions just vibing in [`futures::future`](https://docs.rs/futures/0.3.6/futures/future/index.html#functions).

Let's take a look!

<!-- more -->

# What is a `Future` anyways?

# Creating Futures from thin air

The laziest possible future we can make, is a [`futures::future::lazy`](https://docs.rs/futures/latest/futures/future/fn.lazy.html). It's right there in the name.

It takes a closure and runs it later poll it.

```rust
use core::future::Future;
use futures::executor::block_on;

#[tokio::main]
async fn main() {
    let input = futures::lazy(|_| 1);
    let output = block_on(input)
    tracing::
}
```