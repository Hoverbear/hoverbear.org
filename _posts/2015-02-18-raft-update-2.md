---
layout: post
title:  "Raft: Progress on the Log"
tags:
 - Raft
 - Rust
 - CSC466
 - CSC462
---

I've spent the majority of my free time this last week working on [Raft](https://github.com/hoverbear/raft). As you can see from this [issue](https://github.com/Hoverbear/raft/issues/1) I've been mostly working on the idea of transactions.

A lot has taken shape in the codebase. It still will panic at `unimplemented!()` about 300ms after you start a node, but "That's a feature!"

> Note: All interfaces and code are not final, and are for educational and interest purposes.

## Hacking up a Persistent Log

Probably one of the coolest little projects I worked on was writing the `persistent_state` of a `RaftNode`. This is the data that the Raft protocol requires be written on stable storage each update.

	/// Persistent state
    /// **Must be updated to stable storage before RPC response.**
    pub struct PersistentState<T: Encodable + Decodable + Send + Clone> {
        current_term: u64,
        voted_for: Option<u64>,      // request_vote cares if this is `None`
        log: File,
        last_index: u64,             // The last index of the file.
    }

So, the reason this needs to be written to disk is so that in theory if we have a crash, we can recover. I haven't implemented resuming from a previous log, but I think that'll be a fun thing to do.

Here's what a log looks like right now:

	➜  raft git:(master) ✗ cat /tmp/test_path
                       0                    0
    1 IkZvbyI
    2 IkJhciI

The first line is where we store `current_term` and `voted_for` (in that order). All previous lines are pairs of `$term  $V` where `V` is the base64 encoded JSON encoded version of `T`, which is anything that implemented `Decode` and `Encode`.

> I'd really like to not Base64 encode JSON encoded data. If you have a suggestion, please open an issue! I'm currently looking at using [bincode](https://github.com/TyOverby/bincode) instead. See [this issue](https://github.com/Hoverbear/raft/issues/4).

My reasoning for what `V` looks like is that I'm using `\n` to delimit index entries for the log, so any sort of output that I store can't have any `\n` symbols. In theory I could sanitize my input, but I'd argue that the cost of sanitization would be less than just Base64 encoding it.

### On New Toys

After using them, new `fs` and `io` modules are pretty sweet (At the time of writing this is `rustc 1.0.0-nightly (b63cee4a1 2015-02-14 17:01:11 +0000)`).

Working with the new `Result<T>` was a bit weird as we used to use `Result<T,E>`. The new `Result<T>` handles almost identical in my experience (and you don't need to specify long errors in every function definition!).

### Creating Files

This was, surprisingly, a bit of a stumbling block for me. `File::open()` gives you read access, while `File::create()` gives you write, but if you're hoping to open a file then *read and write* to it, you'll need to use [`OpenOptions`](http://doc.rust-lang.org/std/fs/struct.OpenOptions.html).

    let mut open_opts = OpenOptions::new();
    open_opts.read(true);
    open_opts.write(true);
    open_opts.create(true);
    let mut file = open_opts.open(&log_path).unwrap();


### Manipulating Files

Working with files means you generally deal with `Cursor`s into the file. You can navigate around a file like so:

	let start =
    	self.log.seek(io::SeekFrom::Start(0));
    let offset_from_start =
    	self.log.seek(io::SeekFrom::Start(8));
	let very_end =
    	self.log.seek(io::SeekFrom::End(0));
    let current =
    	self.log.seek(io::SeekFrom::Current(0));

This is key, because it controls your position in the file for *most* other operations. You can try it out with the code below on the [playpen](http://is.gd/rnOgNO).

    #![feature(io)]
    #![feature(fs)]
    #![feature(path)]
    use std::fs::OpenOptions;
    use std::io::{Read, Write, Seek, SeekFrom};
    fn main() {
        let mut open_opts = OpenOptions::new();
        open_opts.read(true);
        open_opts.write(true);
        open_opts.create(true);
        let mut file = open_opts.open(&Path::new("/tmp/test")).unwrap();
        let mut read = String::new();

        write!(&mut file, "Foo bar baz").unwrap();
        file.seek(SeekFrom::End(-3)).unwrap();
        file.read_to_string(&mut read).unwrap();
        println!("{}", read); // Outputs "baz"

        read = String::new();

        file.seek(SeekFrom::End(-7)).unwrap();
        write!(&mut file, "dog").unwrap();
        file.seek(SeekFrom::Start(0)).unwrap();
        file.read_to_string(&mut read).unwrap();
        println!("{}", read); // Outputs "Foo dog baz"
    }


Now that we can write into files, how do we make sure we have a consistent space for data? The first line of our log contains two `u64`s which can take up to 20 digits each. Using this, we can modify our `write!()` call to use more specialize formatting options.

    write!(&mut self.log, "{:20} {:20}\n",
    	self.current_term, self.voted_for.unwrap_or(0))

The `{:20}` is a formatting option that ensures it takes up consistent space. [More on that here](http://doc.rust-lang.org/std/fmt/#syntax).


### Scanning Through

Since we have a handle on moving around our file cursor we can start using other things like `.chars()` on the file to get it to spit out characters.

> Make sure to `.seek()` then build your iterator, otherwise ownership woes will be upon you!

	/// Moves `line` lines into the file. Purposefully goes "one extra" line because the first line is metadata.
    /// Returns the number of bytes containing `line` lines.
    fn move_to(&mut self, line: u64) -> io::Result<u64> {
        // Gotcha: The first line is NOT a log entry.
        let mut lines_read = 0u64;
        self.log.seek(io::SeekFrom::Start(0)); // Take the start.
        // Go until we've reached `line` new lines.
        let _ = self.log.by_ref().chars().skip_while(|opt| {
            match *opt {
                Ok(val) => {
                    if val == '\n' {
                        lines_read += 1;
                        if lines_read > line { // Greater than here because the first line is a bust.
                            false // At right location.
                        } else {
                            true // Not done yet, more lines to go.
                        }
                    } else {
                        true // Not a new line.
                    }
                },
                _ => false // At EOF. Nothing more.
            }
        }).next(); // Side effects.
        self.log.seek(io::SeekFrom::Current(0)) // Where are we?
    }

As you can see, the `move_to()` function's main traversing is not done by `seek()`, it's done by an iterator! Once we set the cursor to `Start(0)` we can set up an iterator with `log.by_ref().chars().skip_while()`. `by_ref()` gets us a reference so we don't stumble into *move* issues. `.chars()` lets us pull `char` types instead of `u8`. `.skip_while()` lets us walk over the file, disgarding values as we finish looking at them.

Finally, at the end you might notice a `.next()`, this is because iterators are lazy... So up until that's called, nothing is actually even done! Very neat.

Looking forward, I'd like to not require going from the start forward every `.move_to()` call.

### Retrieving an Entry

Now that we can effectively scan through the file and get the correct position, how do we retrieve entries? Here is what `retrieve_entry` looks like (Note there is `retrieve_entries` too which is very similar):

    pub fn retrieve_entry(&mut self, index: u64) -> io::Result<(u64, T)> {
        // Move to the correct line.
        let position = self.move_to(index);
        let mut chars = self.log.by_ref()
            .chars()
            // Only go until the end of the file, `None`
            .take_while(|val| val.is_ok())
            // Drop anything not `Some(val)`
            .filter_map(|val| val.ok())
            // Take the line.
            .take_while(|&val| val != '\n')
            // Bring it into a String.
            .collect::<String>();
        let mut splits = chars.split(' ');
        // Use a scope!
        let term = {
            // `.and_then()` is great for dealing with Options.
            let chunk = splits.next()
                .and_then(|v| v.parse::<u64>().ok());
            match chunk {
                Some(v) => v,
                None => return Err(io::Error::new(io::ErrorKind::InvalidInput, "Could not parse term.", None)),
            }
        };
        let encoded = {
            let chunk = splits.next();
            match chunk {
                Some(v) => v,
                None => return Err(io::Error::new(io::ErrorKind::InvalidInput, "Could not parse encoded data.", None)),
            }
        };
        // Decode the value.
        let decoded: T = PersistentState::decode(encoded.to_string())
            .ok().expect("Could not unwrap log entry.");
        Ok((term, decoded))
    }

This code makes use of iterators, scopes, and options in, what I consider, a fairly clean way. After moving to the correct line, `chars` takes in one line of the file and it gets chunked into two pieces along a delimiter. Then the values of that chunk iterator are parsed.

One stumbling block I had was that `v.parse::<u64>()` returned [`<F as FromStr>::Err`](http://doc.rust-lang.org/std/str/trait.StrExt.html#tymethod.parse) instead of an `IoError` like `io::Result<_>` expects. This means that I couldn't just `try!()` the expression. Looking at [`io::Error`](http://doc.rust-lang.org/std/io/struct.Error.html) I was able to find the `InvalidInput` variant that suited my needs.

### Purging and Appending

Part of the Raft protocol dictates that purging and appending must be able to happen to the log. Here's purge:

    /// Do *not* invoke this unless you update the `last_index`!
    fn purge_from_bytes(&mut self, from_bytes: u64) -> io::Result<()> {
        self.log.set_len(from_bytes) // Chop off the file at the given position.
    }
    /// Removes all entries from `from` to the last entry, inclusively.
    pub fn purge_from_index(&mut self, from_line: u64) -> io::Result<()> {
        let position = try!(self.move_to(from_line));
        self.last_index = from_line - 1;
        self.purge_from_bytes(position)
    }

Since purging will always remove all lines **after** a given line, we can just use `.set_len()`, which is convienent since otherwise the only real way I've seen to remove "some" lines is to read in the file and write it back out again entirely, which kind of sucks.

I split `purge_from_bytes()` and `purge_from_index()` up because `append_entries()` will use it. Here it is:


    /// Appends `entries` after `prev_log_index` and `prev_log_term`.
    pub fn append_entries(&mut self, prev_log_index: u64, prev_log_term: u64,
                          entries: Vec<(u64, T)>) -> io::Result<()> {
        // TODO: No checking of `prev_log_index` & `prev_log_term` yet... Do we need to?
        let position = try!(self.move_to(prev_log_index + 1));
        let number = entries.len();
        try!(self.purge_from_bytes(position)); // Update `last_log_index` later.
        for (term, entry) in entries {
            // TODO: I don't like the "doubling" here. How can we do this better?
            write!(&mut self.log, "{} {}\n", term, PersistentState::encode(entry));
        }
        self.last_index = if prev_log_index == 0 {
            number as u64 - 1
        } else { prev_log_index + number as u64 };
        Ok(())
    }

You'll notice the first line is a `// TODO:` because there are no safety checks to make sure that things are as they should be. The semantics of these checks are specified in the Raft paper, and should be easy to implement, I just haven't gotten to it yet! (Midterm week, yuck!) Otherwise, the code for this is fairly straightforward.


### Testing

One of my favorite things about Rust is the built in tooling for testing. Here's what the start of my log test looks like:

    #[test]
    fn test_persistent_state() {
        let path = Path::new("/tmp/test_path");
        fs::remove_file(&path.clone());
        let mut state = PersistentState::new(0, path.clone());
        // Add 0, 1
        assert_eq!(state.append_entries(0, 0,
            vec![(0, "Zero".to_string()),
                 (1, "One".to_string())]),
            Ok(()));
        // Check index.
        assert_eq!(state.get_last_index(), 1);
        // Check 0
        assert_eq!(state.retrieve_entry(0),
            Ok((0, "Zero".to_string())));
        // Check 0, 1
        assert_eq!(state.retrieve_entries(0, 1),
            Ok(vec![(0, "Zero".to_string()),
                    (1, "One".to_string())
            ]));
        // ...

Let me be clear **I love this.** It makes it so easy to unit test code. One gotcha I discovered is that `cargo test` captures all your stdout... So you can do `cargo test -- --nocapture` to disable that!

## Explore and Help!

> https://github.com/Hoverbear/raft

Would you like to explore, give feedback, or contribute? Please do! Publicly you can just make an issue on Github, or privately just shoot me an email. (I'm sure you can find it on Github or here...)

**Discussion of this post is on [Reddit](https://www.reddit.com/r/rust/comments/2wctv2/raft_update_2_hacking_up_the_log/).**
