---
layout: post
title: "A Journey into Iterators"

tags:
  - Rust
  - Tutorials
---

One of my favorite features of Rust is iterators. They are a fast, safe, 'lazy' way of working with data structures, streams, and other more creative applications.

> You can play along on http://play.rust-lang.org/ and by browsing [here](http://doc.rust-lang.org/core/iter/index.html). This article is not a subtitute for the documentation or experience.

## Our First Iterator

Having everything twice as much is great, right? Let's take a set of values and double it!

    fn main() {
    	// First, we get a set of values.
        let input = [1, 2, 3];
        // Create an iterator over them.
        let iterator = input.iter();
        // Specify things to do along the chain.
        let mapped = iterator.map(|&x| x * 2);
        // Do something with the output.
        let output = mapped.collect::<Vec<usize>>();
        println!("{:?}", output);
    }
Okay first some important things to note, even from this simple example:

* `.iter()` can be used on many different types.
* Declare a value, **then** create an iterator over it. Otherwise, the value will not live long enough to be iterated over. (Iterators are lazy, and do not necessarily own their data.)
* `.collect::<Vec<usize>>()` iterates over the entire iterator and places their values into the type of data collection we specify. (If you feel like writing your own data structure, have a look at [this](http://doc.rust-lang.org/std/iter/trait.FromIterator.html#tymethod.from_iter).)
* It can be used and chained! You don't necessarily need to `.collect()` values at the end of a `.map()` call.

## `n` at a Time

You can access the next element in an iterator with `.next()`. If you'd like a batch you can use `.take(n)` to create a new iterator that goes over the next `n` elements. Have a few you don't care about? Use `.skip(n)` to discard `n` elements.

    fn main() {
        let vals = [ 1, 2, 3, 4, 5];
        let mut iter = vals.iter();
        println!("{:?}", iter.next());
        println!("{:?}", iter.skip(2).take(2)
            .collect::<Vec<_>>());
    }
    // Ouputs:
    // Some(1)
	// [4, 5]

## Observing Laziness

We talked about how Iterators are lazy, but our first example didn't really demonstrate that. Let's use `.inspect()` calls to observe evaluation.

    fn main() {
        let input = [1, 2, 3];
        let iterator = input.iter();
        let mapped = iterator
            .inspect(|&x| println!("Pre map:\t{}", x))
            .map(|&x| x * 10) // This gets fed into...
            .inspect(|&x| println!("First map:\t{}", x))
            .map(|x| x + 5)   // ... This.
            .inspect(|&x| println!("Second map:\t{}", x));
        mapped.collect::<Vec<usize>>();
    }

The output is:

    Pre map:    1
    First map:  10
    Second map: 15
    Pre map:    2
    First map:  20
    Second map: 25
    Pre map:    3
    First map:  30
    Second map: 35

As you can see, the map functions are only evaluated as the iterator is moved through. (Otherwise we would see `1`, `2`, `3`, `10`, ...)

> Note how `.inspect()` only provides its function a `&x` instead of a `&mut` or the value itself. This prevents mutation and ensures that your inspection won't disturb the data pipeline.

This has some really cool implications, for example, we can have infinite or cycling iterators.

    fn main() {
        let input = [1, 2, 3];
        // This tells the iterator to cycle over itself.
        let cycled = input.iter().cycle();
        let output = cycled.take(9)
            .collect::<Vec<&usize>>();
        println!("{:?}", output);
    }
    // Outputs [1, 2, 3, 1, 2, 3, 1, 2, 3]



## Something In Common

Don't get hung up thinking that `[1, 2, 3]` and it's ilk are the only things you can use iterators on.

Many data structures support this style, we can use things like Vectors and VecDeques as well! Look for things that implement [`iter()`](http://doc.rust-lang.org/std/?search=iter%28%29).

    std::collections::VecDeque;

    fn main() {
    	// Create a Vector of values.
        let input = vec![1, 2, 3];
        let iterator = input.iter();
        let mapped = iterator.map(|&x| {
                return x * 2;
            });
        // Gather the result in a RingBuf.
        let output = mapped.collect::<VecDeque<_>>();
        println!("{:?}", output);
    }
    // Outputs [2, 4, 6]

Notice how here we collect into a VecDeque? That's because it implements [`FromIterator`](http://doc.rust-lang.org/std/iter/trait.FromIterator.html).

Now you're probably thinking, *"Ah hah! I bet you can't use a HashMap or tree or something, Hoverbear!"* Well, you're wrong! You can!

    use std::collections::HashMap;
    fn main() {
        // Initialize an input map.
        let mut input = HashMap::<u64, u64>::new();
        input.insert(1, 10); // Type inferred here.
        input.insert(2, 20);
        input.insert(3, 30);
        // Continue...
        let iterator = input.iter();
        let mapped = iterator.map(|(&key, &value)| {
                return (key, value * 10);
            });
        let output = mapped.collect::<Vec<_>>();
        println!("{:?}", output);
    }
	// [(1, 100), (3, 300), (2, 200)]

When we're iterating over a HashMap the `.map()` function changes to accept a tuple, and `.collect()` recieves tuples. Of course, you can collect back into a HashMap (or whatever), too.

Did you notice how the ordering changed? HashMap's aren't necessarily in order. Be aware of this!

> Try changing the code to build a `Vec<(u64, u64)>` into a `HashMap`.

## Writing an Iterator

Okay so we've seen a taste of the kind of things that might offer iterators, but we can also make our own. What about an iterator that counts up indefinitely?

    struct CountUp {
        current: usize,
    }

    impl Iterator for CountUp {
        type Item = usize;
        // The only fn we need to provide for a basic iterator.
        fn next(&mut self) -> Option<usize> {
            self.current += 1;
            Some(self.current)
        }
    }

    fn main() {
        // In more sophisticated code use `::new()` from `impl CountUp`
        let iterator = CountUp { current: 0 };
        // This is an infinite iterator, only take so many.
        let output = iterator.take(20).collect::<Vec<_>>();
        println!("{:?}", output);
    }
    // Outputs [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]

We didn't have to call `.iter()` here, and that makes sense, since we're actually implementing an iterator. (Not transforming something into an iterator like before.)

> Try changing the `current` and `.take()` values.

See how we could use `.take()` and other functions without having to implement them separately for our new iterator? If you look at [the docs](http://doc.rust-lang.org/core/iter/index.html#traits) of for `iter` you'll see that there are various traits like [`Iterator`](http://doc.rust-lang.org/core/iter/trait.Iterator.html), [`RandomAccessIterator`](http://doc.rust-lang.org/core/iter/trait.RandomAccessIterator.html).

## Out on the Range with Ranges

Throughout the following examples you'll see use of the `x..y` syntax. This creates a [`Range`](http://doc.rust-lang.org/1.0.0-beta.3/std/ops/struct.Range.html). They implement `Iterator`	so we don't need to call `.iter()` on them. You can also use `(0..100).step_by(2)` if you want to use specific step increments if you're using them as `Iterator`s.

Note that they are open ended, and not inclusive.

	0..5 == [ 0, 1, 2, 3, 4, ]
    2..6 == [ 2, 3, 4, 5, ]

We can also index into our collections.

	fn main() {
        let range = (0..10).collect::<Vec<usize>>();
        println!("{:?}", &range[..5]);
        println!("{:?}", &range[2..5]);
        println!("{:?}", &range[7..]);
    }
    // Outputs:
    // [0, 1, 2, 3, 4]
    // [2, 3, 4]
    // [7, 8, 9]

> Gotcha: Using `.step_by()` doesn't work this way since [`StepBy`](http://doc.rust-lang.org/1.0.0-beta.3/std/iter/struct.StepBy.html) doesn't implement `Idx` and [`Range`](http://doc.rust-lang.org/1.0.0-beta.3/std/ops/struct.Range.html) does.


## Chaining and Zipping

Putting together interators in various ways allows for some very nice, expressive code.

    fn main() {
        // Demonstrate Chain
        let first = 0..5;
        let second = 5..10;
        let chained = first.chain(second);
        println!("Chained: {:?}", chained.collect::<Vec<_>>());
        // Demonstrate Zip
        let first = 0..5;
        let second = 5..10;
        let zipped = first.zip(second);
        println!("Zipped: {:?}", zipped.collect::<Vec<_>>());
    }
    // Chained: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    // Zipped: [(0, 5), (1, 6), (2, 7), (3, 8), (4, 9)]

`.zip()` allows you to merge iterators, while `.chain()` effectively creates an "extended" iterator. Yes, there is an [`.unzip()`](http://doc.rust-lang.org/1.0.0-beta.3/std/iter/trait.Iterator.html#method.unzip).

> Try using `.zip()` on two `usize` slices then `.collect()` the resulting tuples to build up a HashMap.

## Getting Inquisistive

`.count()`, `.max_by()`, `.min_by()`, `.all()`, and `.any()`, are common ways to inquire into an iterator.


	#![feature(core)] // Must be run on nightly at time of publishing.
	#[derive(Eq, PartialEq, Debug)]
    enum BearSpecies { Brown, Black, Polar, Grizzly }

    #[derive(Debug)]
    struct Bear {
        species: BearSpecies,
        age: usize
    }

    fn main() {
        let bears = [
            Bear { species: BearSpecies::Brown, age: 5 },
            Bear { species: BearSpecies::Black, age: 12 },
            Bear { species: BearSpecies::Polar, age: 15 },
            Bear { species: BearSpecies::Grizzly, age: 16 },
        ];
        // Max/Min of a set.
        let oldest = bears.iter().max_by(|x| x.age);
        let youngest = bears.iter().min_by(|x| x.age);
        println!("Oldest: {:?}\nYoungest: {:?}", oldest, youngest);
        // Any/All
        let has_polarbear = bears.iter().any(|x| {
            x.species == BearSpecies::Polar
        });
        let all_minors = bears.iter().all(|x| {
            x.age <= 18
        });
        println!("At least one polarbear?: {:?}", has_polarbear);
        println!("Are they all minors? (<18): {:?}", all_minors);
    }
    // Outputs:
    // Oldest: Some(Bear { species: Grizzly, age: 16 })
    // Youngest: Some(Bear { species: Brown, age: 5 })
    // At least one polarbear?: true
    // Are they all minors? (<18): true

> Try using the same iterator all of the above calls. `.any()` is the only one that borrows mutably, and won't work the same as the others. This is because it might not necessarily consume the entire iterator.

## Filter, Map, Red... Wait... Fold

If you're used to Javascript like me, you probably expect the holy trinity of `.filter()`, `.map()`, `.reduce()`. Well, they're all there in Rust too, but `.reduce()` is called `.fold()` which I kind of prefer.

A basic example:

	fn main() {
    	let input = 1..10;
    	let output = input
        	.filter(|&item| item % 2 == 0) // Keep Evens
        	.map(|item| item * 2) // Multiply by two.
        	.fold(0, |accumulator, item| accumulator + item);
    	println!("{}", output);
	}

Of course, don't start trying to be too clever, the above could simply be:

    fn main() {
        let input = 1..10;
        let output = input
            .fold(0, |acc, item| {
                if b % 2 == 0 {
                    acc + (item*2)
                } else {
                    acc
                }
            });
        println!("{}", output);
    }

The ability to approach problems like this in multiple ways allows Rust to be quite flexible and expressive.

## Split & Scan

There is also [`scan`](https://doc.rust-lang.org/std/iter/trait.Iterator.html#method.scan) if you need a variation of folding which yeilds the result each time. This is useful if you're waiting for a certain accumulated amount and wish to check on each iteration.

Splitting an iterator up into two parts is possible. You can just use a simple grouping function that returns a boolean with [`partition`](https://doc.rust-lang.org/std/iter/trait.aIterator.html#method.partition).

Let's use the two concepts to split up a big slice, group it be evens and odds, then progressively sum them up and make sure that the some of the evens is always less than the sum of the odds. (This is because `even` starts at 0.)

    fn main() {
        let set = 0..1000;
        let (even, odd): (Vec<_>, Vec<_>) = set.partition(|&n| n % 2 == 0);
        let even_scanner = even.iter().scan(0, |acc, &x| { *acc += x; Some(*acc) });
        let odd_scanner  = odd.iter().scan(0, |acc, &x| { *acc += x; Some(*acc) });
        let even_always_less = even_scanner.zip(odd_scanner)
            .all(|(e, o)| e <= o);
        println!("Even was always less: {}", even_always_less);
    }
    // Outputs:
    // Even was always less: true

Scanning can be used to provide things like a moving average. This is useful when reading through files, data, and sensors. Partitioning is a common task when shuffling through data.

Another common goal is to group elements together based on a specific value. Now, if you're expecting something like [`_.groupBy()`](https://lodash.com/docs#groupBy) from Lodash it's not quite that simple. Consider: Rust has `BTreeMap`, `HashMap`, `VecMap`, and other data types, our grouping method should not be opinionated.

To use a simple example, let's make an infinite iterator that cycles from 0 to 5 inclusively. In your own code these could be complex structs or tuples, but for now, simple integers are fine. We'll group them into into three categories, 0s, 5s, and the rest.

    use std::collections::HashMap;

    #[derive(Debug, PartialEq, Eq, Hash)]
    enum Kind { Zero, Five, Other }

    fn main() {
        let values = 0..6; // Not inclusive.
        let cycling = values.cycle();
        // Group them into a HashMap.
        let grouped = cycling.take(20).map(|x| {
            // Return a tuple matching the (key, value) desired.
            match x {
                x if x == 5 => (Kind::Five, 5),
                x if x == 0 => (Kind::Zero, 0),
                x => (Kind::Other, x),
            }
        // Accumulate the values
        }).fold(HashMap::<Kind, Vec<_>>::new(), |mut acc, (k, x)| {
            acc.entry(k).or_insert(vec![]).push(x);
            acc
        });
        println!("{:?}", grouped);
    }
    // Outputs: {Zero: [0, 0, 0, 0], Five: [5, 5, 5], Other: [1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1]}


> It's kind of pointless to store all those replicated values. Try having this example return the number of occurances instead of the values. As a further exploration try using this method on a more complex value like a `struct`, you can also change what keys are used.

## Flanked

The [`DoubleEndedIterator`](http://doc.rust-lang.org/1.0.0-beta.3/std/iter/trait.DoubleEndedIterator.html) trait is useful for certain purposes. For example, when you need the behavior of both of queue and a stack.


    fn main() {
        let mut vals = 0..10;
        println!("{:?}", vals.next());
        println!("{:?}", vals.next_back());
        println!("{:?}", vals.next());
        println!("{:?}", vals.next_back());
    }
    // Some(0)
    // Some(9)
    // Some(1)
    // Some(8)


# Play on your own!

This is a good time for you to take a break, get some tea, and crack open the [Playpen](https://play.rust-lang.org/). Try changing one of the above examples, fiddle with some new things in the API docs below, and generally have a good time.

* [`std::collections`](http://doc.rust-lang.org/1.0.0-beta.3/std/collections/)
* [`std::iter`](http://doc.rust-lang.org/1.0.0-beta.3/std/iter/index.html)

If you get stuck, don't panic! Try googling the error if it befuddles you, Rust has activity on the `*.rust-lang.org` domain as well as Github and Stack Exchange. You are also welcome to email me or visit us on [IRC](https://chat.mibbit.com/?server=irc.mozilla.org&channel=%23rust).

We're just scratching the surface... A vast world awaits us.

![Getting ready to explore](/assets/images/2015/05/photo-1425136738262-212551713a58-1.jpg)
