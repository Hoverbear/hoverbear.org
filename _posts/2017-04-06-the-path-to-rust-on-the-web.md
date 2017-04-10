---
layout: post
title: "The Path to Rust on the Web"

image: /assets/images/2017/04/path.jpg
image-credit: "Mario Klassen"

tags:
  - Rust
  - Tutorials

# published: false
---

Recently there has been quite a bit of talk about *WebAssembly*, a new format for code for the web. It is a compile target for languages like C and Rust that enables us to write, and run, code from these languages in our browser.

In the interest of learning more about this technology (and to avoid writing more Javascript) let's explore together and get our hands dirty!

> **Disclaimer:** WebAssembly is stabilized, but most implementations are not. The information contained here may become out of date or be incorrect, despite working at the time of writing.

Before we start please make sure you're using the current (or developer) version of Firefox or Chrome. You can check out `about:config` or `chrome://flags/` and make sure `wasm` related things are enabled.

## What Are We Looking At?

[*WebAssembly*](http://webassembly.org/) (or *wasm*) describes an *execution environment* which browsers can implement within their Javascript Virtual Machines. It's a way to run code in place of, or alongside, our Javascript.

WebAssembly can be thought of as similar to [*asm.js*](http://asmjs.org/). Indeed, we can use [*Emscripten*](http://emscripten.org/) compiler to target both.

Most existing documentation discusses how to build C, C++, or Rust into wasm, but there is nothing excluding languages like [Ruby](ruby.dj) or Python from working as well.

## Installing The Tools

We'll need two things to get started with WebAssembly and Rust, assuming you already have a functional development environment otherwise (That is, you have `build-essential`, XCode, or the like installed.)

First, Rust. You can review [here](https://hoverbear.org/2017/03/03/setting-up-a-rust-devenv/#setting-up-rust-via-rustup) for a more long winded explanation of how to do this, or you can just run the following, accept the defaults, and then `source $HOME/.cargo/env`:

```bash
curl https://sh.rustup.rs -sSf | sh
```

Next we'll add the `wasm32-unknown-emscripten` compile target via `rustup`:

```bash
rustup target add wasm32-unknown-emscripten
```

We can use this command to install other targets, found via `rustup target list`, as well.

Next we need to set up Emscripten via [`emsdk`](http://kripken.github.io/emscripten-site/docs/getting_started/downloads.html). We'll use the *incoming* version of Emscripten in order to get the best output.

```bash
curl https://s3.amazonaws.com/mozilla-games/emscripten/releases/emsdk-portable.tar.gz | tar -xv -C ~/
cd ~/emsdk-portable
./emsdk update
./emsdk install sdk-incoming-64bit
./emsdk activate sdk-incoming-64bit
```

At this point Emscripten is installed. The last command will instruct us how to add the binaries to our path for permanent usage, or we can just `source ./emsdk_env.sh` for temporary fun.

At this point `emcc -v` should report something similar to this:

```bash
$ emcc -v
INFO:root:(Emscripten: Running sanity checks)
emcc (Emscripten gcc/clang-like replacement + linker emulating GNU ld) 1.37.9
clang version 4.0.0 (https://github.com/kripken/emscripten-fastcomp-clang/ d4b1e0785f1ee15ab78207de4380e82e3407c6ea) (https://github.com/kripken/emscripten-fastcomp/ 09aaa022c31e247bfb7b00882372733e6b27f007) (emscripten 1.37.9 : 1.37.9)
Target: x86_64-apple-darwin16.4.0
Thread model: posix
InstalledDir: /Users/hoverbear/emsdk-portable/clang/fastcomp/build_incoming_64/bin
INFO:root:(Emscripten: Running sanity checks)
```

Now, let's kick the tires a bit!

## First Experiment: Standalone Executable

In our first experiment we'll compile some Rust code into wasm and have it run in the browser console. We'll try a basic code samples to ensure things are working as we expect. We won't try to do any crate importing, DOM manipulation, or network access yet, but that's coming later!

Let's create our project, we'll use this same project for our future experiments as well.

```bash
cargo init wasm-demo --bin
```

Then we'll put our first code sample into `src/main.rs`:

```rust
#[derive(Debug)]
enum Direction { North, South, East, West }

fn is_north(dir: Direction) -> bool {
    match dir {
        Direction::North => true,
        _ => false,
    }
}

fn main() {
    let points = Direction::South;
    println!("{:?}", points);
    let compass = is_north(points);
    println!("{}", compass);
}
```

Running this normally yields what we would expect:

```bash
$ cargo run
   Compiling wasm-demo v0.1.0 (file:///Users/hoverbear/git/rust/wasm-demo)
    Finished dev [unoptimized + debuginfo] target(s) in 0.89 secs
     Running `target/debug/wasm-demo`
South
false
```

Now, let's get the same thing in our browser! We can build our executable for the wasm target by using the `--target` flag.

```bash
$ cargo build --target=wasm32-unknown-emscripten --release
$ tree target
target
└── wasm32-unknown-emscripten
    └── release
        ├── build
        ├── deps
        │   ├── wasm_demo-9c23ae9a241f12fa.asm.js
        │   ├── wasm_demo-9c23ae9a241f12fa.js
        │   └── wasm_demo-9c23ae9a241f12fa.wasm
        ├── examples
        ├── incremental
        ├── native
        ├── wasm-demo.d
        └── wasm-demo.js
```

`cargo` created several files in `target/wasm32-unknown-emscripten/release/deps/` for us. Of primary interest are the `.wasm` and `.js` files.

Why do we get both a `wasm` and a `js`? Wasn't the whole point of this to not use Javascript? Turns out we need some Javascript glue code to fetch, initialize, and configure it.

At this point we can't really *use* the created files, since we don't have a webpage to import them into! Let's work on that. We can create a `site/index.html` with the following content:

```html
<html>
    <head>
        <script>
            // This is read and used by `site.js`
            var Module = {
                wasmBinaryFile: "site.wasm"
            }
        </script>
        <script src="site.js"></script>
    </head>
    <body></body>
</html>
```

Next we need to set up some way to get the generated files from the `target/` folder into the `site/` folder. `make` is a good solution for this, so let's make a `Makefile`.

```makefile
SHELL := /bin/bash

all:
	cargo build --target=wasm32-unknown-emscripten --release
	mkdir -p site
	cp target/wasm32-unknown-emscripten/release/deps/*.wasm site/site.wasm
	cp target/wasm32-unknown-emscripten/release/deps/*[!.asm].js site/site.js
```

Finally, test it with `make`.

```bash
$ tree site
site
├── index.html
├── site.js
└── site.wasm
```

Let's test our generated code by running `python -m SimpleHTTPServer`, browsing to [`http://localhost:8000/site/`](http://localhost:8000/site/), and opening the browser console.

In my console I get:

```
trying binaryen method: native-wasm
asynchronously preparing wasm
binaryen method succeeded.
The character encoding of the HTML document was not declared. The document will render with garbled text in some browser configurations if the document contains characters from outside the US-ASCII range. The character encoding of the page must be declared in the document or in the transfer protocol.
South
false
```

Excellent! It worked!

## Second Experiment: Imports

In our first example we just used a basic enum and some print statements, nothing too exciting. Let's do something more exciting and work with iterators.

```rust
use std::collections::HashMap;
use Direction::*;

#[derive(Debug, PartialEq)]
enum Direction { North, South, East, West }

fn main() {
    let mut users_facing = HashMap::new();
    users_facing.insert("Alice", North);
    users_facing.insert("Bob", South);
    users_facing.insert("Carol", East);

    let users_not_facing_north = users_facing.iter()
        .filter(|&(_, d)| *d != North)
        .collect::<HashMap<_,_>>();
    println!("{:?}", users_not_facing_north);
}

```

Building this code again with `make` we can navigate to the page again in our browser. This should output:

```rust
{"Carol": East, "Bob": South}
```

Excellent! So importing things from `std` seems to work okay. How about other crates? Let's try using `itertools`. Add the following to the `Cargo.toml`:

```toml
[dependencies]
itertools = "*"
```

Then we can go and try to use it.

```rust
extern crate itertools;

use itertools::Itertools;
use Direction::*;


#[derive(Debug, PartialEq, Eq, Hash)]
enum Direction { North, South, East, West }

fn main() {
    let directions = vec![North, North, South, East, West, West];

    let unique_directions = directions.iter()
        .unique()
        .collect::<Vec<_>>();
    println!("{:?}", unique_directions);
}
```

Building and visiting the page again we see the following output:

```
[North, South, East, West]
```

Okay that was simple! What about something a bit more complicated, like `serde`, which lets us serialize and deserialize various formats? This will be important for an application which needs to parse responses from APIs!

Changing the `Cargo.toml` and the `main.rs`:

```toml
[dependencies]
serde_json = "*"
serde_derive = "*"
serde = "*"
```

```rust
extern crate serde_json;
#[macro_use] extern crate serde_derive;

#[derive(Serialize, Deserialize, Debug)]
enum Direction { North, South, East, West }

#[derive(Serialize, Deserialize, Debug)]
struct Example {
    favorite_animal: String,
    favorite_direction: Direction
}

fn main() {
    let data = r#" { "favorite_animal": "Bear", "favorite_direction": "North" } "#;
    let parsed: Example = serde_json::from_str(data).unwrap();
    println!("{:?}", parsed);
}
```

Building, and viewing it in the browser console yields:

```rust
Example { favorite_animal: "Bear", favorite_direction: North }
```

Awesome!

## Third Experiment: Calling From Javascript

It's also possible to use generated wasm as a library and call the generated code from within Javascript. This has its own set of complications though.

In order to do this, at least for now, we need to run `rustup override set nightly` for our project so we use nightly. This is because stable seems to optimize out the exported functions, while nightly does not.

WebAssembly only supports a limited number of [value types](https://github.com/WebAssembly/design/blob/master/Semantics.md#types):

* `i32`: 32-bit integer
* `i64`: 64-bit integer
* `f32`: 32-bit floating point
* `f64`: 64-bit floating point

Notice how this doesn't include strings or other more satisfying types. That's ok! We can still use a function called `Module.cwrap` to define the parameters and expected return values of the wasm exported functions.

Writing this interaction code means that on the Rust side of things we have to treat it as though we're interacting with C. This can make some things a bit complicated, on the bright side it means writing more (native) FFI later will be much easier.

So, let's write a basic function which returns a String from Rust into Javascript.

```rust
use std::os::raw::c_char;
use std::ffi::CString;
use std::collections::HashMap;

#[no_mangle]
pub fn get_data() -> *mut c_char {
    let mut data = HashMap::new();
    data.insert("Alice", "send");
    data.insert("Bob", "recieve");
    data.insert("Carol", "intercept");
    
    let descriptions = data.iter()
        .map(|(p,a)| format!("{} likes to {} messages", p, a))
        .collect::<Vec<_>>();

    CString::new(descriptions.join(", "))
        .unwrap()
        .into_raw()
}

fn main() {
    // Deliberately blank.
}
```

First thing you might notice is that we have a `main()` function which is blank. This is on purpose, we're going to define that in Javascript! We'll edit the `index.html` to write a bit of new code for this purpose.

```html
<html>
    <head>
        <script>
            // This is read and used by `site.js`
            var Module = {
                wasmBinaryFile: "site.wasm",
                onRuntimeInitialized: main,
            };
            function main() {
                let get_data = Module.cwrap('get_data', 'string', []);
                console.log(get_data());
            }
        </script>
        <script src="site.js"></script>
    </head>
    <body></body>
</html>
```

The final argument of `cwrap` is an array of argument types, which we don't use in this case.

It's also possible to call the function via `Module._get_data()` but you'll notice that it returns a pointer to a memory location, not a string.

## Fourth Experiment: Calling Javascript From Rust

There isn't a tremendous amount of writing about this topic, the best resource I was able to find was in the ['Interacting with code'](https://kripken.github.io/emscripten-site/docs/porting/connecting_cpp_and_javascript/Interacting-with-code.html#implement-c-in-javascript) section of the Emscripten documentation.

The basic concept is that when `emcc` goes and does its job it includes a `library.js` file which we can add functions to via the `--js-library` flag. These functions can return values, or do things like run `alert("Blah blah")`.

In order to do this we need to create a `site/utilities.js` file containing the following:

```javascript
'use strict';

var library = {
  get_data: function() {
    var str = "Hello from JS.";
    alert(str);

    // Not needed for numerics.
    var len = lengthBytesUTF8(str);
    var buffer = Module._malloc(len);
    Module.stringToUTF8(str, buffer, len);

    return buffer;
  },
};

mergeInto(LibraryManager.library, library);
```

Then the HTML:

```html
<html>
    <head>
        <script>
            // This is read and used by `site.js`
            var Module = {
                wasmBinaryFile: "site.wasm",
            };
        </script>
        <script src="site.js"></script>
    </head>
    <body></body>
</html>
```

Lastly, the Rust code:

```rust
#![feature(link_args)]

#[cfg_attr(target_arch="wasm32", link_args = "\
    --js-library site/utilities.js\
")]
extern {}

use std::os::raw::c_char;
use std::ffi::CStr;

extern {
    fn get_data() -> *mut c_char;
}

fn get_data_safe() -> String {
    let data = unsafe {
        CStr::from_ptr(get_data())
    };
    data.to_string_lossy()
        .into_owned()
}

fn main() {
    let data = get_data_safe();
    println!("{:?}", data);
}
```

If we build this and load the page we'll get an alert, and see `"Hello from JS"` printed out on the console.

The good thing is it works. The bad thing is that it is rather complex to do. Hopefully it will get better in the future.

> I'm not entirely happy with this situation, if you have any ideas how we can do this better please let me know!

## Fifth Experiment: Using The Web Platform

As we've discovered by now, the barrier between our compiled code and Javascript is a bit annoying. It'd be quite handy if we could just write everything in Rust and avoid dealing with Javascript except where absolutely needed.

Luckly for us, there is a crate called [`rust-webplatform`](https://github.com/tcr/rust-webplatform/) that was started. It allows for convienent DOM manipulation and provides some helpers for doing Javascript. It's still a bit rough around the edges, but the foundations are there.


To get started, let's add `webplatform = "*"` to our dependencies. Then we can use some slightly modified sample code from the repo:

```rust
extern crate webplatform;

fn main() {
    let document = webplatform::init();
    let body = document.element_query("body")
        .unwrap();
    body.html_append("\
        <h1>This header brought to you by Rust</h1>\
        <button>Click me!</button>\
    ");
    
    let button = document.element_query("button")
        .unwrap();
    button.on("mouseenter", move |_| {
        println!("Mouse entered!");
        body.html_append("<p>Mouse entered!</p>");
    });
    button.on("click", |_| {
        println!("Clicked!");
        webplatform::alert("Clicked!");
    });

    webplatform::spin();
}
```

Building our project you should see:

* DOM elements created when the wasm is loaded.
* DOM elements being created when your mouse goes over the button.
* An alert when you click on the button.

Due to the youth of the library there isn't much in the way of examples or documentation, so be prepared to fumble around in the dark. For example, I discovered the key to getting some events and `println!()` working was to use `webplatform::spin()`.

> If you're looking for something to contribute, this crate would likely be an excellent place to do so! There's a bunch of work to be done and you could really make a difference for the blossoming Rust wasm community!

## Outlook

The future of Rust on the web is quite bright! Much of the foundations already exist, as we've seen in this article, and the Rust community is actively interested in improving the experience. The Rust repository even has an [`A-wasm`](https://github.com/rust-lang/rust/issues?utf8=%E2%9C%93&q=label%3AA-wasm%20) tag for issues! 

There are currently discussions about moving from `emcc` to the nascent LLVM wasm backend which you can track [here](https://github.com/rust-lang/rust/issues/38804). This may make significant parts of this article obselete, which is very exciting!

The ecosystem around wasm in Rust is still young, and now is a great time to get involved and help shape the future!

> Special thanks to [Jan-Erik (Badboy)](https://fnordig.de/) for his workshop at Rust Belt Rust 2016, his hard work on this ecosystem, his advice while writing this post, for reviewing this before publishing, and most of all for being my valued friend. May we continue to hack in the same circles.

> This post was supported by [Asquera](http://asquera.de/) and is an extension of the wasm chapter in our [Three Days of Rust](https://github.com/skade/rust-three-days-course/) course. If you'd like to hire us for training, consulting, or developing in Rust (or anything else) please get in touch with me at [andrew.hobden@asquera.de](mailto:andrew.hobden@asquera.de).