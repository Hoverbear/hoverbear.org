---
layout: post
title: "Optional Arguments in Rust"
description: "Exploring Rust UX and API design."

image: /assets/images/2018/11/trees.jpg
image-credit: "A Hobden; Port Renfrew, BC"

tags:
- Rust
- Tutorials

---

When designing an API for your crate one topic which can come is how to handle optional arguments. Let's explore our `Option`s in Rust!



## We Don't Have Splats or Multiple Implementations

Rust currently does not offer functions with variadic or optional arguments. This means this is not possible:

```rust
fn impossible(val: bool) {}
fn impossible(val: bool, other: bool) {}
fn impossible(val: bool, rest: bool...) {}
```

Coming from languages such as JS or Ruby, you might miss this functionality. In particular, I found myself often looking for a way to have an optional configuration or value I pass in.

```rust
// In the context of an configuration structure for a client:
client.connect("127.0.0.1")?;
client.connect("127.0.0.1", custom_config)?;
```

> **Note on scope:** I'm not interested in writing about how to deal with variadic arguments at this time. If you are insatiable about this, try it yourself, consider a macro, reference `format!()`.

## Just Throw Another Function At It!

Since that's not possible, what's a viable alternative?

The most obvious is to have **two functions.** There is nothing technically wrong with that. It's perfectly reasonable, and results in a very acceptable API. There is no tricks, and it's understandable immediately:

```rust
fn connect(addr: String) -> Result<Self, io::Error> {
    Self::connect_with_config(addr, Config::default())
}

fn connect_with_config(addr: String, config: Config) -> Result<Self, io::Error> {
    // ...
}
```

But this is a very specific example. There are sometimes general cases where this is **not** as reasonable. For example, let's say we have a send message that **usually** takes a payload, but supports no payload (for pings, for example). At this point the technique just looks strange, you either end up with `message_with_payload()` everywhere, a `ping()` function, or a `message_without_payload()` function. Using your imagination you might be able to think of other examples in your own code where you've encountered this.

## We've got `Option`s

The next logical step, which starts to harness Rust's abstractions, is using an **optional type**.

```rust
fn message(addr: String, maybe_payload: Option<Vec<u8>>) -> Result<u64, io::Error> {
    // ...
    if let Some(payload) = maybe_payload {
        // Off you go...
    }
    // ...
}
// Using it:
message("127.0.0.1", Some(vec![1,2,3]))?;
message("127.0.0.1", None)?;
```

This certainly gets the job done! Now we can have one function that can internally handle if the value is provided or not. It does clutter up the API a bit, but it seems now we have these odd feeling `Some(_)` and `None` variants loitering around.

We boil the problem down with some generics, to get a better idea of what we're trying to accomplish and to support some microbenchmarks.

```rust
fn value_arg<Thing>(thing: Thing) -> Thing {
    thing
}

fn optional_arg<Thing>(thing: Option<Thing>) -> Thing
where Thing: Default {
    thing.unwrap_or(Thing::default())
}
```

As you can see, these are deliberately as simple as we can possibly make them while not allowing it to be optimized away, they return their value and allow the bencher to accept their output.

Let's get rid of the `Some(_)`. We can use **generics** via `impl Trait`, inline generic, or where clauses.

### Aside: Why I like `impl Trait`

I think it enables a more succinct style, better semantics for some use cases, and helps avoid one particular usability mistake that is easy to make. Consider the following:

```rust
fn handles_a_pair_of_stringish<Stringish>(first: Stringish, second: Stringish)
where Stringish: AsRef<str> {
    // ...
}

fn handles_a_pair_of_varying_stringish(first: impl AsRef<str>, second: impl AsRef<str>) {
    // ...
}


#[test]
fn send_stringishes_of_difference_type() {
    handles_a_pair_of_stringish("foo".to_string(), "foo"); // This won't compile!
    handles_a_pair_of_varying_stringish("foo".to_string(), "foo");
}
```

I think in these situations, `impl Trait` is an effective choice for readability and flexibility. I do **not** encourage you to use it everywhere, for everything. Strive for readability and understandability, not "slick"/arcane APIs.

## A Generic Implementation

In order to refine this design we can pay attention to some key trait implementations:

* [`impl<T> Into<Option<T>> for T`](https://doc.rust-lang.org/std/option/enum.Option.html#impl-From%3CT%3E)
* [`impl<T> Default for Option<T>`](https://doc.rust-lang.org/std/option/enum.Option.html#impl-Default)

This means we can do the following:

```rust
fn optional_arg_with_into<Thing>(
    thing: impl Into<Option<Thing>>
) -> Thing
where Thing: Default {
    thing.into().unwrap_or(Thing::default())
}

#[test]
fn verify_assemptions() {
    optional_arg_with_into(Vec::<u64>::default());
    optional_arg_with_into(vec![1_u64, 2, 3]);
    let out: Vec<u64> = optional_arg_with_into(None::<Vec<u64>>); // Type hinting
}
```

In this very limited demo code we need to provide quite a bit of type hinting to the `None` argument. This is not normally the case for more projects with a non-trivial codebase.

At this point, you're able to leverage a couple basic traits (`Default` and `From`) to give your users a more flexible API.

## Caveats

As you may have noticed in the last example, in the case of very simple code this can get pretty verbose. That's because we're not doing anything with the return/argument values. As your project grows the need for the hinting will disappear, as the compiler will be able to make more inferences about the types of things.

Using this technique can reduce your ability to flexibly accept things that turn into the inner argument. Eg a `U` where `impl From<U> for T`. You might need to jump through some hoops. Getting around this the easy way will force your users to do `T::from(u)` in the argument position when calling. Still, not too bad.

## Benchmarking

Let's make sure that adding this flexibility doesn't have a huge performance impact on our code. I used Criterion and wrote a small suite for our demo code. Since the code is trivial (it basically just converts and converts back), we can explore the cost of just doing this operation. Here is the entire bench code:


```rust
#[macro_use(criterion_main, criterion_group)] extern crate criterion;
use criterion::Criterion;

criterion_main!(benches);
criterion_group!(benches, optional_args::group);

mod optional_args {
    use criterion::Criterion;

    fn value_arg<Thing>(thing: Thing) -> Thing {
        thing
    }

    fn optional_arg<Thing>(thing: Option<Thing>) -> Thing
    where Thing: Default {
        thing.unwrap_or(Thing::default())
    }

    fn optional_arg_with_into<Thing>(
        thing: impl Into<Option<Thing>>
    ) -> Thing
    where Thing: Default {
        thing.into().unwrap_or(Thing::default())
    }

    pub(crate) fn group(c: &mut Criterion) {
        c.bench_function("value 1_u64", |b| b.iter(|| -> u64 {
            let value = value_arg(1_u64);
            value + 1
        }));
        c.bench_function("optional Some(1_u64)", |b| b.iter(|| -> u64 {
            let value = optional_arg(Some(1_u64));
            value + 1
        }));
        c.bench_function("optional_into 1_u64", |b| b.iter(|| -> u64 {
            let value = optional_arg_with_into(1_u64);
            value + 1
        }));
        c.bench_function("optional_into Some(1_u64)", |b| b.iter(|| -> u64 {
            let value: u64 = optional_arg_with_into(Some(1_u64));
            value + 1
        }));
        c.bench_function("optional_into (u64) None", |b| b.iter(|| -> u64 {
            let value: u64 = optional_arg_with_into(None);
            value + 1
        }));
        c.bench_function("optional_into 1_u8.into()", |b| b.iter(|| -> u64 {
            let value: u64 = optional_arg_with_into(u64::from(1_u8));
            value + 1
        }));
        c.bench_function("optional_into Vec<u64>::new()", |b| b.iter(|| -> Vec<u64> {
            let value: Vec<u64> = optional_arg_with_into(Vec::<u64>::new());
            value
        }));
        c.bench_function("optional_into (Vec<u64>) None", |b| b.iter(|| -> Vec<u64> {
            let value: Vec<u64> = optional_arg_with_into(None::<Vec<u64>>);
            value
        }));
    }
}
```

It's pretty snappy, enough so I'm still not *entirely* convinced it's not getting optimized out somehow. Computers are sneaky.

```
value 1_u64             time:   [264.11 ps 264.50 ps 264.97 ps]                        
Found 15 outliers among 100 measurements (15.00%)
  1 (1.00%) low mild
  5 (5.00%) high mild
  9 (9.00%) high severe

optional Some(1_u64)    time:   [263.41 ps 263.86 ps 264.44 ps]                                 
Found 18 outliers among 100 measurements (18.00%)
  3 (3.00%) low mild
  4 (4.00%) high mild
  11 (11.00%) high severe

optional_into 1_u64     time:   [258.67 ps 259.43 ps 260.37 ps]                                
Found 7 outliers among 100 measurements (7.00%)
  3 (3.00%) high mild
  4 (4.00%) high severe

optional_into Some(1_u64)                                                                            
                        time:   [252.95 ps 253.41 ps 253.94 ps]
Found 6 outliers among 100 measurements (6.00%)
  2 (2.00%) high mild
  4 (4.00%) high severe

optional_into (u64) None                                                                            
                        time:   [256.31 ps 256.89 ps 257.70 ps]
Found 12 outliers among 100 measurements (12.00%)
  3 (3.00%) high mild
  9 (9.00%) high severe

optional_into 1_u8.into()                                                                            
                        time:   [255.77 ps 256.33 ps 257.04 ps]
Found 12 outliers among 100 measurements (12.00%)
  1 (1.00%) low mild
  7 (7.00%) high mild
  4 (4.00%) high severe

optional_into Vec<u64>::new()                                                                             
                        time:   [853.18 ps 858.14 ps 863.70 ps]
Found 4 outliers among 100 measurements (4.00%)
  4 (4.00%) high mild

optional_into (Vec<u64>) None                                                                             
                        time:   [830.59 ps 833.04 ps 835.56 ps]
```

# What We Learnt & Takeaways

We learnt there are many options when it comes to API design with Rust. During our exploration we noted that choosing to declare our functions semantically, and/or enabling a more flexible API doesn't have to cost much.

If you're interested in learning more about enabling flexible APIs in Rust, I'd reccomend exploring the [Guidelines](https://rust-lang-nursery.github.io/api-guidelines/flexibility.html). I'd also reccomend exploring the [Builder Pattern](https://doc.rust-lang.org/1.0.0/style/ownership/builders.html), since it's generally more well used in Rust.

Thanks for reading! Hope to use your lovely code soon. 😉

> **P.S.** If you are looking for a **senior level** position, are passionate about this topic, and have experience with distributed systems, safety critical systems, data structures, networking, and chaos engineering please [email me](operator@hoverbear.org). We can chat about the possibility of working on my team at [PingCAP](http://pingcap.com/) doing open source ecosystem work for [TiKV](https://github.com/tikv/tikv) and its dependencies. In the future you would get to take on mentoring new juniors, open source contributors, and community members at large. Globally remote friendly, competitive salaries, travel coverage for speaking, very minority friendly (location, race, sexuality, gender, etc).
