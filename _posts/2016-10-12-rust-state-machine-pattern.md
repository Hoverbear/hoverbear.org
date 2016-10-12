---
layout: post
title: "Pretty State Machine Patterns in Rust"

image: /assets/images/2016/10/machine.jpg
image-credit: "Samuel Zeller"

tags:
  - Rust

published: false
---

Lately I've been thinking a lot about the *patterns* and *structures* which we program with. It's really wonderful to start exploring a project and see familiar patterns and styles which you've already used before. It makes it easier to understand and empowers you to start working on the project faster.

Perhaps you're working on a new project and realize that you need to do something in the same was as you did in another project. This *thing* might not be a functionality or a library, it might not be something which you can encode into some clever macro. Instead, it may be simply a pattern, or a structural concept which addresses a problem nicely.

One interesting pattern that is commonly applied to problems is that of the 'State Machine'. Let's take some time to consider what exactly we mean when we say that, and why they're interesting.

> Throughout this post you can run all examples in [the playground](http://play.rust-lang.org/), I typically use 'Nightly' out of habit.

## Founding Our Concepts

There are a **lot** of resources and people topical articles about state machines out there on the internet. Even more so, there are a lot of **implementations** of state machines.

Just to get to this web page you used one. You can model TCP as a state machine. You can model HTTP requests as one too. You can model any *regular* language, such as a regex without look behinds, as a state machine. They're everywhere, hiding inside things we use every day.

So, a State Machine is any **'machine'** which has a set of **'states'** and **'transitions'** defined between them.

When we talk about a machine we're referring to the abstract concept of something which *does something*. For example, your 'Hello World!' function is a machine. It is started and eventually outputs what we expect it to. Some model which you use to interact with your database is just the same. We'll regard our most basic machine simply as a `struct` that can be created and destroyed.

```rust
struct Machine;

fn main() {
  let my_machine = Machine; // Create.
  // `my_machine` is destroyed when it falls out of scope below.
}
```

States are a way to reason about *where* a machine is in its process. For example, we can think about a bottle filling machine as an example. The machine is in a 'waiting' state when it is waiting for a new bottle. Once it detects a bottle it moves to the 'filling' state. Upon detecting the bottle is filled it enters the 'done' state. After the bottle is left the machine we return to the 'waiting' state.

A key takeaway here is that none of the states have any information relevant for the other states. The 'filling' state doesn't care how long the 'waiting' state waited. The 'done' state doesn't care about what rate the bottle was filled at. Each state has *discrete responsibilities and concerns*. The natural way to consider these is as an `enum`.

```rust
enum BottleFillerState {
  Waiting { waiting_time: std::time::Duration },
  Filling { rate: usize },
  Done,
}

struct BottleFiller {
  state: BottleFillerState,
}
```

Using an `enum` in this way means all the states are mutually exclusive, you can only be in one at a time. Rust's 'fat enums' allow us to have each of these states to carry data with them as well. As far as our current definition is concerned, everything is totally okay.

But there is a bit of a problem here. When we described our bottle filling machine above we described three transitions: `Waiting -> Filling`, `Filling -> Done`, and `Done -> Waiting`. We never described `Waiting -> Done` or `Done -> Filling`, those don't make sense!

This brings us to the idea of transitions. One of the nicest things about a true state machine is we never have to worry about our bottle machine going from `Done -> Filling`, for example. The state machine pattern should **enforce** that this can never happen. Ideally this would be done before we even start running our machine, at compile time.

Let's look again at the transitions we described for our bottle filler in a diagram:

```
  +---------+   +---------+   +------+
  |         |   |         |   |      |
  | Waiting +-->+ Filling +-->+ Done |
  |         |   |         |   |      |
  +----+----+   +---------+   +--+---+
       ^                         |
       +-------------------------+
```

As we can see here there are a finite number of states, and a finite number of transitions between these states. Now, it is possible to have a valid transition between each state and every other state, but in most cases this is not true.

This means moving between a state such as 'Waiting' and 'Filling' should have defined semantics. In our example this can be defined as "There is a bottle in place." In the case of a TCP stream it might be "We have received a FIN packet" which means we need to close out the stream.

## Determining What We Want

Now that we know what a state machine is, how do we represent them in Rust? First, let's think about what we **want** from some pattern.

Ideally, we'd like to see the following characteristics:

* Can only be in one state at a time.
* Each state should able have it's own associated values if required.
* Transitioning between states should have well defined semantics.
* It should be possible to have some level of shared state.
* Only explicitly defined transitions should be permitted.
* We shouldn't need to allocate memory for **all** states. Perhaps just the largest sized state.
* Any error messages should be easy to understand.
* We shouldn't need to resort to heap allocations to do this. Everything should be possible on the stack.
* The type system should be harnessed to our greatest ability.
* As many errors as possible should be at **compile-time**.

So if we could have a design pattern which allowed for all these things it'd be truly fantastic. Having a pattern which allowed for most would be pretty good too.

## Exploring Possible Implementation Options

With a type system as powerful and flexible as Rusts we should be able to represent this. The truth is: there are a number of ways to try, each teaches us lessons.

### A Second Shot with Enums

As we saw above the most natural way to attempt this is an `enum`, but we noted already that you can't control which transitions are actually permitted in this case. So can we just wrap it? We sure can! Let's take a look:

```rust
enum State {
    Waiting { waiting_time: std::time::Duration },
    Filling { rate: usize },
    Done
}

struct StateMachine { state: State }

impl StateMachine {
    fn new() -> Self {
        StateMachine {
            state: State::Waiting { waiting_time: std::time::Duration::new(0, 0) }
        }
    }
    fn to_filling(&mut self) {
        self.state = match self.state {
            // Only Waiting -> Filling is valid.
            State::Waiting { .. } => State::Filling { rate: 1 },
            // The rest should fail.
            _ => panic!("Invalid state tranistion!"),
        }
    }
    // ...
}

fn main() {
    let mut state_machine = StateMachine::new();
    state_machine.to_filling();
}
```

At first glance it seems okay. But notice some problems?

* Invalid transition errors happen at runtime, which is awful!
* This only prevents invalid transitions *outside* of the module, since the private fields can be manipulated freely inside the module. For example, `state_machine.state = State::Done` is perfectly valid inside the module.
* Every function we implement that works with the state has to include a match statement!

However this does have some good characteristics:

* The memory required to represent the state machine is only the size of the largest state. This is because a fat enum is only as big as its biggest variant.
* Everything happens on the stack.
* Transitioning between states has well defined semantics... It either works or it crashes!

Now you might be thinking "Hoverbear you could totally wrap the `to_filling()` output with a `Result<T,E>` or have an `InvalidState` variant!" But let's face it: That doesn't make things that much better, if at all. Even if we get rid of the runtime failures we still have to deal with a lot of clumsiness with the match statements and our errors would still only be found at runtime! Ugh! We can do better, I promise.

So let's keep looking!

### Structure Based Transitions

So what if we just used a set of structs? We could have them all implement traits which all states should share. We could use special functions that transitioned the type into the new type even! How would it look?

```rust
// This is some functionality shared by all of the state.
trait SharedFunctionality {
    fn get_shared_value(&self) -> usize;
}

struct Waiting {
    waiting_time: std::time::Duration,
    // Value shared by all states.
    shared_value: usize,
}
impl Waiting {
    fn new() -> Self {
        Waiting {
            waiting_time: std::time::Duration::new(0,0),
            shared_value: 0,
        }
    }
    // Consumes the value!
    fn to_filling(self) -> Filling {
        Filling {
            rate: 1,
            shared_value: 0,
        }
    }
}
impl SharedFunctionality for Waiting {
    fn get_shared_value(&self) -> usize {
        self.shared_value
    }
}

struct Filling {
    rate: usize,
    // Value shared by all states.
    shared_value: usize,
}
impl SharedFunctionality for Filling {
    fn get_shared_value(&self) -> usize {
        self.shared_value
    }
}

// ...

fn main() {
    let in_waiting_state = Waiting::new();
    let in_filling_state = in_waiting_state.to_filling();
}
```

Gosh that's a buncha code! So the idea here was that all states have some common shared values along with their own specialized values. As you can see from the `to_filling()` function we can consume a given 'Waiting' state and transition it into a 'Filling' state. Let's do a little rundown:

* Transition errors are caught at runtime! For example you can't even create a `Filling` state without first starting with a `Waiting` state.
* Transition enforcement happens everywhere.
* When a transition between states is made the old value is **consumed** instead of just modified. We could have done this with the enum example above as well though.
* We don't have to `match` all the time.
* Memory consumption is still lean, at any given time the size is that of the state.

There are some downsides though:

* There is a bunch of code repetition. You have to implement the same functions and traits for multiple structures.
* It's not always clear what values are shared between all states and just one. Updating code later could be a pain due to this.
* Since the size of the state is variable we end up needing to wrap this in an `enum` as above for it to be usable where the state machine is simply one component of a more complex system. Here's what this could look like:

```rust
enum State {
    Waiting(Waiting),
    Filling(Filling),
    Done(Done),
}

fn main() {
    let in_waiting_state = State::Waiting(Waiting::new());
    // This doesn't work since the `Waiting` struct is wrapped! We need to `match` to get it out.
    let in_filling_state = State::Filling(in_waiting_state.to_filling());
}
```

As you can see, this isn't very ergonomic. We're getting closer to what we want though. The idea of moving between distinct types seems to be a good way forward! Before we go try something entirely different though, let's talk about a simple way to change our example that could enlighten further thinking.

The Rust standard library defines two highly related traits: [`From`](https://doc.rust-lang.org/std/convert/trait.From.html) and [`Into`](https://doc.rust-lang.org/std/convert/trait.Into.html) that are extremely useful and worth checking out. An important thing to note is that implementing one of these automatically implements the other. In general implementing `From` is preferable as it's a bit more flexible. We can implement them very easily for our above example like so:

```rust
// ...
impl From<Waiting> for Filling {
    fn from(val: Waiting) -> Filling {
        From {
            rate: 1,
            shared_value: val.shared_value,
        }
    }
}
// ...
```

Not only does this give us a common function for transitioning, but it also is nice to read about in the source code! This reduces mental burden on us and makes it easier for readers to comprehend. *Instead of implementing custom functions we're just using a pattern already existing.* Building our pattern on top of already existing patterns is a great way forward.

So this is cool, but how do we deal with all this nasty code repetition and the repeating `shared_value` stuff? Let's explore a bit more!

### Growing Sophistication

In this adventure we'll combine lessons and ideas from the first two, along with a few new ideas, to get something more satisfying. The core of this idea is to harness the power of generics. Let's take a look at the barest possible strutures representing this:

```rust
struct StateMachine<S> {
    shared_value: usize,
    state: S
}

// The following states can be the 'S' in StateMachine<S>

struct Waiting {
    waiting_time: std::time::Duration,
}

struct Filling {
    rate: usize,
}

struct Done;
```

So here we're actually building the state into the type signature of the StateMachine itself. A state machine in the 'Filling' state is `StateMachine<Filling>` which is just **awesome** since it means when we see it as part of an error message or something we know immediately what state the machine is in.

From there we can go ahead and implement `From<T>` for some of these specific generic variants like so:

```rust
impl From<StateMachine<Waiting>> for StateMachine<Filling> {
    fn from(val: StateMachine<Waiting>) -> StateMachine<Filling> {
        StateMachine {
            shared_value: val.shared_value,
            state: Filling {
                rate: 1,
            }
        }
    }
}

impl From<StateMachine<Filling>> for StateMachine<Done> {
    fn from(val: StateMachine<Filling>) -> StateMachine<Done> {
        StateMachine {
            shared_value: val.shared_value,
            state: Done,
        }
    }
}
```

Defining a starting state for the machine looks like this:

```rust
impl StateMachine<Waiting> {
    fn new(shared_value: usize) -> Self {
        StateMachine {
            shared_value: shared_value,
            state: Waiting {
                waiting_time: std::time::Duration::new(0, 0),
            }
        }
    }
}
```

So how does it look to change between two states? Like this:

```rust
fn main() {
    let in_waiting = StateMachine::<Waiting>::new(0);
    let in_filling = StateMachine::<Filling>::from(in_waiting);
}
```

Alternatively if you're doing this inside of a function whose type signature restricts the possible outputs it might look like this:

```rust
fn transition_the_states(val: StateMachine<Waiting>) -> StateMachine<Filling> {
    val.into()
}
```

What do the **compile time** error messages look like?

```
error[E0277]: the trait bound `StateMachine<Done>: std::convert::From<StateMachine<Waiting>>` is not satisfied
  --> <anon>:50:22
   |
50 |     let in_filling = StateMachine::<Done>::from(in_waiting);
   |                      ^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: the following implementations were found:
   = help:   <StateMachine<Filling> as std::convert::From<StateMachine<Waiting>>>
   = help:   <StateMachine<Done> as std::convert::From<StateMachine<Filling>>>
   = note: required by `std::convert::From::from`
```

It's pretty clear what's wrong from that. The error message even hints to us some valid transitions!
