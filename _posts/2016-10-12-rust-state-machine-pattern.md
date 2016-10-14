---
layout: post
title: "Pretty State Machine Patterns in Rust"

image: /assets/images/2016/10/machine.jpg
image-credit: "Samuel Zeller"

tags:
  - Rust

# published: false
---

Lately I've been thinking a lot about the *patterns* and *structures* which we program with. It's really wonderful to start exploring a project and see familiar patterns and styles which you've already used before. It makes it easier to understand the project, and empowers you to start working on the project faster.

Sometimes you're working on a new project and realize that you need to do something in the same was as you did in another project. This *thing* might not be a functionality or a library, it might not be something which you can encode into some clever macro or small crate. Instead, it may be simply a pattern, or a structural concept which addresses a problem nicely.

One interesting pattern that is commonly applied to problems is that of the 'State Machine'. Let's take some time to consider what exactly we mean when we say that, and why they're interesting.

> Throughout this post you can run all examples in [the playground](https://play.rust-lang.org/), I typically use 'Nightly' out of habit.

## Founding Our Concepts

There are a **lot** of resources and topical articles about state machines out there on the internet. Even more so, there are a lot of **implementations** of state machines.

Just to get to this web page you used one. You can model TCP as a state machine. You can model HTTP requests with one too. You can model any *regular* language, such as a regex, as a state machine. They're everywhere, hiding inside things we use every day.

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

A key takeaway here is that none of the states have any information relevant for the other states. The 'filling' state doesn't care how long the 'waiting' state waited. The 'done' state doesn't care about what rate the bottle was filled at. Each state has *discrete responsibilities and concerns*. The natural way to consider these *variants* is as an `enum`.

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

This means moving between a state such as 'Waiting' to a state such as 'Filling' should have defined semantics. In our example this can be defined as "There is a bottle in place." In the case of a TCP stream it might be "We have received a FIN packet" which means we need to finish closing out the stream.

## Determining What We Want

Now that we know what a state machine is, how do we represent them in Rust? First, let's think about what we **want** from some pattern.

Ideally, we'd like to see the following characteristics:

* Can only be in one state at a time.
* Each state should able have its own associated values if required.
* Transitioning between states should have well defined semantics.
* It should be possible to have some level of shared state.
* Only explicitly defined transitions should be permitted.
* Changing from one state to another should **consume** the state so it can no longer be used.
* We shouldn't need to allocate memory for **all** states. No more than largest sized state certainly
* Any error messages should be easy to understand.
* We shouldn't need to resort to heap allocations to do this. Everything should be possible on the stack.
* The type system should be harnessed to our greatest ability.
* As many errors as possible should be at **compile-time**.

So if we could have a design pattern which allowed for all these things it'd be truly fantastic. Having a pattern which allowed for most would be pretty good too.

## Exploring Possible Implementation Options

With a type system as powerful and flexible as Rusts we should be able to represent this. The truth is: there are a number of ways to try, each has valuable characteristics, and each teaches us lessons.

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

### Structures With Transitions

So what if we just used a set of structs? We could have them all implement traits which all states should share. We could use special functions that transitioned the type into the new type! How would it look?

```rust
// This is some functionality shared by all of the states.
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

* Transition errors are caught at compile time! For example you can't even create a `Filling` state accidentally without first starting with a `Waiting` state. (You could on purpose, but this is beside the matter.)
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

### Generically Sophistication

In this adventure we'll combine lessons and ideas from the first two, along with a few new ideas, to get something more satisfying. The core of this is to harness the power of generics. Let's take a look at a fairly bare structure representing this:

```rust
struct BottleFillingMachine<S> {
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

So here we're actually building the state into the type signature of the `BottleFillingMachine` itself. A state machine in the 'Filling' state is `BottleFillingMachine<Filling>` which is just **awesome** since it means when we see it as part of an error message or something we know immediately what state the machine is in.

From there we can go ahead and implement `From<T>` for some of these specific generic variants like so:

```rust
impl From<BottleFillingMachine<Waiting>> for BottleFillingMachine<Filling> {
    fn from(val: BottleFillingMachine<Waiting>) -> BottleFillingMachine<Filling> {
        BottleFillingMachine {
            shared_value: val.shared_value,
            state: Filling {
                rate: 1,
            }
        }
    }
}

impl From<BottleFillingMachine<Filling>> for BottleFillingMachine<Done> {
    fn from(val: BottleFillingMachine<Filling>) -> BottleFillingMachine<Done> {
        BottleFillingMachine {
            shared_value: val.shared_value,
            state: Done,
        }
    }
}
```

Defining a starting state for the machine looks like this:

```rust
impl BottleFillingMachine<Waiting> {
    fn new(shared_value: usize) -> Self {
        BottleFillingMachine {
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
    let in_waiting = BottleFillingMachine::<Waiting>::new(0);
    let in_filling = BottleFillingMachine::<Filling>::from(in_waiting);
}
```

Alternatively if you're doing this inside of a function whose type signature restricts the possible outputs it might look like this:

```rust
fn transition_the_states(val: BottleFillingMachine<Waiting>) -> BottleFillingMachine<Filling> {
    val.into() // Nice right?
}
```

What do the **compile time** error messages look like?

```
error[E0277]: the trait bound `BottleFillingMachine<Done>: std::convert::From<BottleFillingMachine<Waiting>>` is not satisfied
  --> <anon>:50:22
   |
50 |     let in_filling = BottleFillingMachine::<Done>::from(in_waiting);
   |                      ^^^^^^^^^^^^^^^^^^^^^^^^^^
   |
   = help: the following implementations were found:
   = help:   <BottleFillingMachine<Filling> as std::convert::From<BottleFillingMachine<Waiting>>>
   = help:   <BottleFillingMachine<Done> as std::convert::From<BottleFillingMachine<Filling>>>
   = note: required by `std::convert::From::from`
```

It's pretty clear what's wrong from that. The error message even hints to us some valid transitions!

So what does this scheme give us?

* Transitions are ensured to be valid at compile time.
* The error messages about invalid transitions are very understandable and even list valid options.
* We have a 'parent' structure which can have traits and values associated with it that aren't repeated.
* Once a transition is made the old state no longer exists, it is consumed. Indeed, the entire structure is consumed so if there are side effects of the transition on the parent (for example altering the average waiting time) we can't access stale values.
* Memory consumption is lean and everything is on the stack.

There are some downsides still:

* Our `From<T>` implementations suffer from a fair bit of "type noise". This is a highly minor concern though.
* Each `BottleFillingMachine<S>` has a different size, with our previous example, so we'll need to use an enum. Because of our structure though we can do this in a way that doesn't completely suck.

> You can play with this example [**here**](https://is.gd/CyuJlH)

### Getting Messy With the Parents

So how can we have some parent structure hold our state machine without it being a gigantic pain to interact with? Well, this circles us back around to the `enum` idea we had at first.

If you recall the primary problem with the `enum` example above was that we had to deal with no ability to enforce transitions, and the only errors we got were at runtime when we did try.

```rust
enum BottleFillingMachineWrapper {
    Waiting(BottleFillingMachine<Waiting>),
    Filling(BottleFillingMachine<Filling>),
    Done(BottleFillingMachine<Done>),
}
struct Factory {
    bottle_filling_machine: BottleFillingMachineWrapper,
}
impl Factory {
    fn new() -> Self {
        Factory {
            bottle_filling_machine: BottleFillingMachineWrapper::Waiting(BottleFillingMachine::new(0)),
        }
    }
}
```

At this point your first reaction is likely "Gosh, Hoverbear, look at that awful and long type signature!" You're quite right! Frankly it's rather long, but I picked long, explanatory type names! You'll be able to use all your favorite arcane abbreviations and type aliases in your own code. Have at!

```rust
impl BottleFillingMachineWrapper {
    fn step(mut self) -> Self {
        match self {
            BottleFillingMachineWrapper::Waiting(val) => BottleFillingMachineWrapper::Filling(val.into()),
            BottleFillingMachineWrapper::Filling(val) => BottleFillingMachineWrapper::Done(val.into()),
            BottleFillingMachineWrapper::Done(val) => BottleFillingMachineWrapper::Waiting(val.into()),
        }
    }
}

fn main() {
    let mut the_factory = Factory::new();
    the_factory.bottle_filling_machine = the_factory.bottle_filling_machine.step();
}
```

Again you may notice that this works by **consumption** not mutation. Using `match` the way we are above *moves* `val` so that it can be used with `.into()` which we've already determined should consume the state. If you'd really like to use mutation you can consider having your states `#[derive(Clone)]` or even `Copy`, but that's your call.

Despite this being a bit less ergonomic and pleasant to work with than we might want we still get strongly enforced state transitions and all the guarantees that come with them.

One thing you will notice is this scheme **does** force you to handle all potential states when manipulating the machine, and that makes sense. You are reaching into a structure with a state machine and manipulating it, you need to have defined actions for each state that it is in.

Or you can just `panic!()` if that's what you really want. But if you just wanted to `panic!()` then why didn't you just use the first attempt?

> You can see a fully worked example of this Factory example [**here**](https://is.gd/s03IaQ)

## Worked Examples

This is the kind of thing it's always nice to have some examples for. So below I've put together a couple worked examples with comments for you to explore.

### Three State, Two Transitions

This example is very similar to the Bottle Filling Machine above, but instead it **actually** does work, albeit trivial work. It takes a string and returns the number of words in it.

> [Playground link](https://is.gd/4ITDyV)

```rust
fn main() {
    // The `<StateA>` is implied here. We don't need to add type annotations!
    let in_state_a = StateMachine::new("Blah blah blah".into());

    // This is okay here. But later once we've changed state it won't work anymore.
    in_state_a.some_unrelated_value;
    println!("Starting Value: {}", in_state_a.state.start_value);


    // Transition to the new state. This consumes the old state.
    // Here we need type annotations (since not all StateMachines are linear in their state).
    let in_state_b = StateMachine::<StateB>::from(in_state_a);

    // This doesn't work! The value is moved when we transition!
    // in_state_a.some_unrelated_value;
    // Instead, we can use the existing value.
    in_state_b.some_unrelated_value;

    println!("Interm Value: {:?}", in_state_b.state.interm_value);

    // And our final state.
    let in_state_c = StateMachine::<StateC>::from(in_state_b);

    // This doesn't work either! The state doesn't even contain this value.
    // in_state_c.state.start_value;

    println!("Final state: {}", in_state_c.state.final_value);
}

// Here is our pretty state machine.
struct StateMachine<S> {
    some_unrelated_value: usize,
    state: S,
}

// It starts, predictably, in `StateA`
impl StateMachine<StateA> {
    fn new(val: String) -> Self {
        StateMachine {
            some_unrelated_value: 0,
            state: StateA::new(val)
        }
    }
}

// State A starts the machine with a string.
struct StateA {
    start_value: String,
}
impl StateA {
    fn new(start_value: String) -> Self {
        StateA {
            start_value: start_value,
        }
    }
}

// State B goes and breaks up that String into words.
struct StateB {
    interm_value: Vec<String>,
}
impl From<StateMachine<StateA>> for StateMachine<StateB> {
    fn from(val: StateMachine<StateA>) -> StateMachine<StateB> {
        StateMachine {
            some_unrelated_value: val.some_unrelated_value,
            state: StateB {
                interm_value: val.state.start_value.split(" ").map(|x| x.into()).collect(),
            }
        }
    }
}

// Finally, StateC gives us the length of the vector, or the word count.
struct StateC {
    final_value: usize,
}
impl From<StateMachine<StateB>> for StateMachine<StateC> {
    fn from(val: StateMachine<StateB>) -> StateMachine<StateC> {
        StateMachine {
            some_unrelated_value: val.some_unrelated_value,
            state: StateC {
                final_value: val.state.interm_value.len(),
            }
        }
    }
}
```

### A Raft Example

If you've followed my posts for awhile you may know I rather enjoy thinking about Raft. Raft, and a discussion with [**@argorak**](https://twitter.com/Argorak) were the primary motivators behind all of this research.

Raft is a bit more complex than the above examples as it does not just have linear states where `A->B->C`. Here is the transition diagram:

```
+----------+    +-----------+    +--------+
|          +---->           |    |        |
| Follower |    | Candidate +----> Leader |
|          <----+           |    |        |
+--------^-+    +-----------+    +-+------+
         |                         |
         +-------------------------+
```

> [Playground link](https://is.gd/HDZeGR)

```rust
// You can play around in this function.
fn main() {
    let is_follower = Raft::new(/* ... */);
    // Raft typically comes in groups of 3, 5, or 7. Just 1 for us. :)

    // Simulate this node timing out first.
    let is_candidate = Raft::<Candidate>::from(is_follower);

    // It wins! How unexpected.
    let is_leader = Raft::<Leader>::from(is_candidate);

    // Then it fails and rejoins later, becoming a Follower again.
    let is_follower_again = Raft::<Follower>::from(is_leader);

    // And goes up for election...
    let is_candidate_again = Raft::<Candidate>::from(is_follower_again);

    // But this time it fails!
    let is_follower_another_time = Raft::<Follower>::from(is_candidate_again);
}


// This is our state machine.
struct Raft<S> {
    // ... Shared Values
    state: S
}

// The three cluster states a Raft node can be in

// If the node is the Leader of the cluster services requests and replicates its state.
struct Leader {
    // ... Specific State Values
}

// If it is a Candidate it is attempting to become a leader due to timeout or initialization.
struct Candidate {
    // ... Specific State Values
}

// Otherwise the node is a follower and is replicating state it receives.
struct Follower {
    // ... Specific State Values
}

// Raft starts in the Follower state
impl Raft<Follower> {
    fn new(/* ... */) -> Self {
        // ...
        Raft {
            // ...
            state: Follower { /* ... */ }
        }
    }
}

// The following are the defined transitions between states.

// When a follower timeout triggers it begins to campaign
impl From<Raft<Follower>> for Raft<Candidate> {
    fn from(val: Raft<Follower>) -> Raft<Candidate> {
        // ... Logic prior to transition
        Raft {
            // ... attr: val.attr
            state: Candidate { /* ... */ }
        }
    }
}

// If it doesn't receive a majority of votes it loses and becomes a follower again.
impl From<Raft<Candidate>> for Raft<Follower> {
    fn from(val: Raft<Candidate>) -> Raft<Follower> {
        // ... Logic prior to transition
        Raft {
            // ... attr: val.attr
            state: Follower { /* ... */ }
        }
    }
}

// If it wins it becomes the leader.
impl From<Raft<Candidate>> for Raft<Leader> {
    fn from(val: Raft<Candidate>) -> Raft<Leader> {
        // ... Logic prior to transition
        Raft {
            // ... attr: val.attr
            state: Leader { /* ... */ }
        }
    }
}

// If the leader becomes disconnected it may rejoin to discover it is no longer leader
impl From<Raft<Leader>> for Raft<Follower> {
    fn from(val: Raft<Leader>) -> Raft<Follower> {
        // ... Logic prior to transition
        Raft {
            // ... attr: val.attr
            state: Follower { /* ... */ }
        }
    }
}
```

## Alternatives From Feedback

I saw an interesting comment by [I-impv on Reddit](https://www.reddit.com/r/rust/comments/57ccds/pretty_state_machine_patterns_in_rust/d8rhwq4) showing off [this approach based on our examples above](https://play.rust-lang.org/?gist=ee3e4df093c136ced7b394dc7ffb78e1&version=stable&backtrace=0). Here's what they had to say about it:

> I like the way you did it. I am working on a fairly complex FSM myself currently and did it slightly different.
>
> Some things I did different:
>
> * I also modeled the input for the state machine. That way you can model your transitions as a match over (State, Event) every invalid combination is handled by the 'default' pattern
> * Instead of using panic for invalid transitions I used a Failure state, So every invalid combination transitions to that Failure state

I really like the idea of modeling the input in the transitions!

## Closing Thoughts

Rust lets us represent State Machines in a fairly good way. In an ideal situation we'd be able to make `enum`s with restricted transitions between variants, but that's not the case. Instead, we can harness the power of generics and the ownership system to create something expressive, safe, and understandable.

If you have any feedback or suggestions on this article I'd suggest checking out the footer of this page for contact details. I also hang out on Mozilla's IRC as Hoverbear.
