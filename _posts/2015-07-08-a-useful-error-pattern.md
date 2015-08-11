---
layout: post
title: "Collecting Results from Collections"
author: "Andrew Hobden"
tags:
 - Rust
---

I've been playing around with a new project that uses a lot of collections of results, for example `Vec<Result<()>>` and asked some folks on Rust if they new a good way of transforming this into a `Result<Vec<()>>`.

Turns out, `.collect()` can do it for you!

```rust
use std::io::{Error, ErrorKind};

fn main() {
    let results = vec![
        Ok(0),
        Ok(1),
        Ok(2),
        Err(Error::new(ErrorKind::Other, "I'm an error!")),
    ];

    let error = results.into_iter()
        .collect::<Result<Vec<usize>, Error>>();
    println!("{:?}", error);

    let results = vec![
        Ok(0),
        Ok(1),
        Ok(2),
    ];
    let okay = results.into_iter()
        .collect::<Result<Vec<usize>, Error>>();
    println!("{:?}", okay);
}
// Err(Error { repr: Custom(Custom
//     { kind: Other, error: StringError("I\'m an error!")
// }) })
// Ok([0, 1, 2])
```

Isn't that handy! I hope this is useful to your in your projects! [Playpen Link](http://is.gd/KJ4JVs)
