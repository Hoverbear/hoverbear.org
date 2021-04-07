+++
title = "Parsing Arguments in Rust"
aliases = ["2014/11/15/command-line-args-in-rust/"]
template = "blog/single.html"
[taxonomies]
tags = [
  "Rust",
  "Tutorials",
]
+++

I was reading about the [Docopt](http://docopt.org/) project the other day and really liked the standardized approach to `--help` prompts and argument parsing that it offers.

Luckly, there is a [Rust Package](https://github.com/docopt/docopt.rs) to play with!

<!-- more -->

```bash
cargo new --bin foo
cd foo
```

Add `docopt` to your `Cargo.toml`

```toml
# ...
[dependencies.docopt_macros]
git = "git://github.com/docopt/docopt.rs"
```

Now in `foo/src/main.rs`:

```rust
extern crate serialize;
extern crate docopt;

use docopt::Docopt;

// Define a USAGE string.
static USAGE: &'static str = "
Usage: foo [options] <target> <task>
       foo (--help | --version)

Task:
    start          Starts the task.
    stop           Stops the task.
    restart        Restarts the task.

Options:
    -h, --help     Show this help.
    -v, --version  Show the version.
";

// Define the struct that results from those options.
#[deriving(Decodable, Show)]
struct Args {
    arg_target: Option<String>,
    arg_task: Option<Task>,
    flag_help: bool,
    flag_version: bool,
}

// Create a `Task` enum.
#[deriving(Show)]
enum Task { Start, Stop, Restart }
// Teach Rust how to decode the `Task`
impl<E, D: serialize::Decoder<E>> serialize::Decodable<D, E> for Task {
    fn decode(data: &mut D) -> Result<Task, E> {
        let value = try!(data.read_str());
        match value.as_slice() {
            "start" => Ok(Start),
            "stop" => Ok(Stop),
            "restart" => Ok(Restart),
            other => {
                 let err = format!("Could not decode '{}' as task.\nValid options are (start | stop | restart).", other);
                 Err(data.error(err.as_slice()))
             }
        }
    }
}

fn main() {
    let args: Args = Docopt::new(USAGE)
        .and_then(|d| d.decode())
        .unwrap_or_else(|e| e.exit());
    println!("{}", args);
}
```

Now build it, and try some tests:

```bash
cargo build
```

```bash
➜  foo git:(master) ✗ ./target/foo
# Invalid arguments.
#
# Usage: foo [options] <target> <task>
#        foo (--help | --version)
# ➜  foo git:(master) ✗ ./target/foo -h
# Usage: foo [options] <target> <task>
#        foo (--help | --version)
#
# Task:
#     start          Starts the task.
#     stop           Stops the task.
#     restart        Restarts the task.
#
# Options:
#     -h, --help     Show this help.
#     -v, --version  Show the version.
➜  foo git:(master) ✗ ./target/foo -v
# Args { arg_target: None, arg_task: None, flag_help: false, flag_version: true }
➜  foo git:(master) ✗ ./target/foo bar start
# Args { arg_target: Some(bar), arg_task: Some(Start), flag_help: false, flag_version: false }
➜  foo git:(master) ✗ ./target/foo bar stop
# Args { arg_target: Some(bar), arg_task: Some(Stop), flag_help: false, flag_version: false }
➜  foo git:(master) ✗ ./target/foo bar restart
# Args { arg_target: Some(bar), arg_task: Some(Restart), flag_help: false, flag_version: false }
➜  foo git:(master) ✗ ./target/foo bar baz
# Could not decode 'baz' as task.
# Valid options are (start | stop | restart).
➜  foo git:(master) ✗ ./target/foo start
# Invalid arguments.
#
# Usage: foo [options] <target> <task>
#        foo (--help | --version)
```

This works great! The [README](https://github.com/docopt/docopt.rs) of the project also describes a way to use a macro for this, but I quite like this way.
