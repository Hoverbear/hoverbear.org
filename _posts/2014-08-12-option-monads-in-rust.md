---
layout: post
title: "Option Monads in Rust"
author: "Andrew Hobden"
tags:
 - Rust
 - Tutorials
---


One common monadic structure is the `Option` (or `Maybe` in Haskell and other languages) type. This can be seen as an encapsulation type. Consider a function which may fail to produce a meaningful value for certain inputs. For example,

```rust
fn main () {
  // Parses a string into an integer.
  from_str::<int>("4"); // A valid input.
  from_str::<int>("Potato"); // Definitely invalid.
}
```

The `from_str` function cannot return a meaningful value for `"Potato"`. Rust (and many other functional languages) does not have `null`, so what should we return? This is where an `Option` type becomes useful. In our example, instead of returning an `int` type, the `from_str` function returns an `Option<int>` type.

In Rust, the `Option` enum is represented by either `Some(x)` or `None`, where `x` is the encapsulated value. In this way, the `Option` monad can be thought of like a box. It encapsulates the value `x`, where `x` is any type. Rust defines an `Option` as such, where `<T>` and `(T)` denote that it handles a generic type, meaning that `T` could be an `int`, a `str`, a `vec`, or anything else, even other `Option` types.

```rust
enum Option<T> { None, Some(T) }
```

### Value In, Value Out

Since we can see an `Option` as a box, or encapsulation type, we need to be able to put things into the box, or take things out.

Putting a value into an `Option` is delightfully simple. Simply use `Some(x)` or `None` in place of `x` or (an imaginary) `null`. Most of the time, you will receive or return an `Option` based on input, rather than just creating them directly. Here are some examples of different techniques.

```rust
fn main () {
    // Ways to create an Option containing an int.
    let w = Some(3i); // Something
    let x: Option<int> = None; // Nothing
    // Receive from function.
    let y = some_on_even(2); // Something
    let z = some_on_even(3); // Nothing
}

fn some_on_even(val: int) -> Option<int> {
    match val {
        // Matches an even number.
        x if x % 2 == 0 => Some(x),
        // Matches anything else.
        _                     => None
    }
}
```

To take something out of the `Option` we need to be able to extract, or "unwrap" the value. There are a number of ways to do this. Some common methods are with a `match` or `.expect()`.

> If you're seeking to write code that won't crash, avoid `.expect()` and it's cousin `.unwrap()` and use safer alternatives like `unwrap_or_default()` or `unwrap_or()`.

```rust
fn main () {
    // Create an Option containing the value 1.
    let a_monad: Option<int> = Some(1);
    // Extract and branch based on result.
    let value_from_match = match a_monad {
        Some(x) => x,
        None    => 0i // A fallback value.
    };
    // Extract with failure message.
    let value_from_expect = a_monad.expect("No result.");
    // Extract, or get a default value
    let value_or_default = a_monad.unwrap_or_default();
    let value_or_fallback = a_monad.unwrap_or(42i);
}
```

### Not Just a Null

By now, you're probably asking yourself something similar to the following:

> So why not just have `null`? What does an `Option` monad provide that's more?

That's a very good question. What are the benefits of this paradigm?

* **You must handle all possible returns, or lack thereof.** The compiler will emit errors if you don't appropriately handle an `Option`. You can't just *forget* to handle the `None` (or 'null') case.
* **Null doesn't exist.** It's immediately apparent to readers and consumers which functions might not return a meaningful value. Attempting to use a value from an `Option` without handling it results in a compiler error.
* **Values aren't boxed.** `Option` values don't wrap pointers, they wrap values. In order to have a `null`, you necessarily need a pointer. ([Thanks cmr!](http://www.reddit.com/r/rust/comments/2dnx7k/exploring_the_option_monad_with_rust/cjrca88))
* **Composition becomes easy.** The `Option` monad becomes much more powerful when it is used in composition, as its characteristics allow for pipelines to be created which don't need to explicitly handle errors at each step.

Let's take a closer look at the composition idea...

### Composing a Symphony of Functions

Nirvana is being able to compose a series of functions together without introducing a tight dependency between them, such that they could be moved or changed without needing to be concerned with how this might affect the other functions. For example, let's say we have some functions with the following signatures:

```rust
fn log(value: f64)     -> f64; // This could fail. (log(-2) == ??)
fn sqrt(value: f64)    -> f64; // This could fail. (sqrt(-2) == ??)
fn square(value: f64)  -> f64;
fn double(value: f64)  -> f64;
fn inverse(value: f64) -> f64;
```

Quite the little math library we have here! How about we come up with a way to turn `20` into something else, using a round-about pipeline?

```rust
sqrt(-1 * (log(-1 * (20 * 2)))^2)
```

With our little library it'd look something like this:

```rust
// This code will not compile, it's invalid.
// `Null` isn't a real type in Rust.
fn main () {
    let number: f64 = 20.;
    match log(inverse(double(number))) {
        x => {
            match sqrt(square(inverse(x)))) {
                y => println!("The result is {}", y),
                Null => println!(".sqrt failed.")
            }
        },
        Null => println!(".log failed.")
    }
}
```

In this case, we had two functions which could fail, since we didn't have an `Option` type, the author must be aware of and handle possible `Null` values. Note that the onus was on the programmer to know when a `Null` **might** be returned, and **remember** to handle it, not on the compiler.

Let's see what the same code would look like using the `Option` monad. In this example, all of the functions are appropriately defined.

```rust
fn main () {
    let number: f64 = 20.;
    // Perform a pipeline of options.
    let result = Some(number)
        .map(inverse) // Described below.
        .map(double)
        .map(inverse)
        .and_then(log) // Described below.
        .map(square)
        .and_then(sqrt);
    // Extract the result.
    match result {
        Some(x) => println!("Result was {}.", x),
        None    => println!("This failed.")
    }
}
// You can ignore these.
fn log(value: f64) -> Option<f64> {
    match value.log2() {
        x if x.is_normal() => Some(x),
        _                  => None
    }
}
fn sqrt(value: f64) -> Option<f64> {
    match value.sqrt() {
        x if x.is_normal() => Some(x),
        _                  => None
    }
}
fn double(value: f64) -> f64 {
    value * 2.
}
fn square(value: f64) -> f64 {
    value.powi(2 as i32)
}
fn inverse(value: f64) -> f64 {
    value * -1.
}
```

This code handles all possible result branches cleanly, and the author need not explicitly deal with each possible `None` result, they only need to handle the end result. If any of the functions which may fail (called by `and_then()`) do fail, the rest of the computation is bypassed. Additionally, it makes expressing and understanding the pipeline of computations much easier.

`map` and `and_then` (along with a gamut of other functions listed [here](http://doc.rust-lang.org/std/option/type.Option.html)) provide a robust set of tools for composing functions together. Let's take a look, their signatures are below.

```rust
fn map<U>     (self, f: |T| -> U)         -> Option<U>
fn and_then<U>(self, f: |T| -> Option<U>) -> Option<U>
```

### Functor Interface: `.map()`

`map` provides a way to apply a function of the signature `|T| -> U` to an `Option<T>`, returning an `Option<U>`. This is ideal for functions like `double()` which don't return an `Option`.

This call corresponds to `fmap` in Haskell, which is part of a functor. Monads have this trait because every monad is a functor.

### Monad Interface: `.and_then()`

`and_then` allows you to apply a `|T| -> Option<U>` function to an `Option<T>`, returning an `Option<U>`. This allows for functions which may return no value, like `sqrt()`, to be applied.

This call corresponds to `bind` in Haskell and theoretical Monad definitions. Meanwhile unwrapping `Some<T>` or `None` is the equivalent of `return`. (Thanks to [dirkt](http://www.reddit.com/r/rust/comments/2dnx7k/exploring_the_option_monad_with_rust/cjrr48c))

### Examples

**Working with Options in Vectors**. Parsing a vector of strings into integers. Note that Rust's iterators are lazy, so if `collect()` isn't called, the iterator itself could be composed with others.

```rust
fn main () {
    let strings = vec!("4", "12", "foo", "15", "bar", "baz", "1");
    let numbers: Vec<int> = strings.iter()
        // `filter_map` transforms `Vec<&'static str>` to `Vec<int>`
        // Any `None` will be removed,
        // while any `Some` will be unwrapped.
        .filter_map(|&x| from_str::<int>(x))
        // `collect` forces iteration through the lazy iterator.
        .collect();
    println!("{}", numbers);
}
```

**A simple pipeline**. This example takes a strong and splits it into an iterator. `next()` fetches the next token, which is an `Option`.

```rust
fn main () {
    let mut input = "15 Bear".split(' ');
    // Need to pull the number and parse it.
    let number = input.next()
        // Process Option<&'static str> to Option<int>
        .and_then(|x| from_str::<int>(x))
        .expect("Was not provided a valid number.");
    // The next token is our animal.
    let animal = input.next()
        .expect("Was not provided an animal.");
    // Ouput `number` times.
    for x in std::iter::range(0, number) {
        println!("{} {} says hi!", animal, x)
    }
}
```

## Discussion:
* [Reddit Post](http://www.reddit.com/r/rust/comments/2dnx7k/exploring_the_option_monad_with_rust/)
* [Hacker News Post](https://news.ycombinator.com/item?id=8187106)


## Further Resources:

* [Wikipedia's Article](http://en.wikipedia.org/wiki/Monad_(functional_programming))
* [Monads 101](http://www.intensivesystems.net/tutorials/monads_101.html)
* [A Monad Tutorial for Clojure Programmers](http://onclojure.com/2009/03/05/a-monad-tutorial-for-clojure-programmers-part-1/)
* [Clojure.algo.monads](https://github.com/clojure/algo.monads/blob/master/src/main/clojure/clojure/algo/monads.clj)
* [Functors, Applicatives, and Monads in Pictures](http://adit.io/posts/2013-04-17-functors,_applicatives,_and_monads_in_pictures.html)
* [A fistful of monads](http://learnyouahaskell.com/a-fistful-of-monads)
