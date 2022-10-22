+++
title = "Command Execution in Rust"
aliases = ["2014/09/07/command-execution-in-rust/"]
template = "blog/single.html"
[taxonomies]
tags = [
  "Rust",
  "Tutorials",
  "UVic",
]
+++

One of my projects over the upcoming semester is to explore the Linux boot process and the job of the init (initialization) system. The init system is considered **PID 1** and is responsible for a significant portion of userspace functionality. Common init systems on Linux are OpenRC and systemd. One of the key parts of an init system is to spawn new processes, like in command shell.

Executing child processes may be useful to any number of programs, but common applications include:

* Shells
* Init systems
* Launchers
* Interfacing with command line applications

<!-- more -->

# Using libc

If you are familiar with C/C++, or other languages, you may have used one of the following functions:

```c
 int execl(const char *path, const char *arg, ...);
 int execlp(const char *file, const char *arg, ...);
 int execle(const char *path, const char *arg , ..., char * const envp[]);
 int execv(const char *path, char *const argv[]);
 int execvp(const char *file, char *const argv[]);
```

Each of these functions provide some variant of process spawning. Most of these are still available in Rust if you so desire. They can be accessed in [`libc`](http://doc.rust-lang.org/libc/funcs/posix88/unistd/index.html). Note these are unsafe C bindings.

```rust
pub unsafe fn execv(prog: *const c_char, argv: *mut *const c_char) -> c_int
pub unsafe fn execve(prog: *const c_char, argv: *mut *const c_char, envp: *mut *const c_char) -> c_int
pub unsafe fn execvp(c: *const c_char, argv: *mut *const c_char) -> c_int
```

This `unsafe` access is exactly what it says on the box, unsafe. We'll be forced to use C constructs directly and manipulate raw pointers, this is not an ideal scenario. In order to properly use this code we'd need to construct safe wrappers. But surely there is a better way?

# Using std::io::process

The [`std::io::process`](http://doc.rust-lang.org/std/io/process/index.html) module provides robust facilities for spawning child processes. In particular `Command` allows us to build and spawn processes easily.

## Introducing `Command`

`std::io::process::Command`, aliased as `std::io::Command`, is a type that acts as a process builder. The [`Command::new()`](http://doc.rust-lang.org/std/io/process/struct.Command.html#method.new) command sets up several sane defaults for the program for you.

```rust
fn new<T: ToCStr>(program: T) -> Command
```

The various builder functions allow for customization over the defaults, which are:

* No arguments to the program
* Inherit the current process's environment
* Inherit the current process's working directory
* A readable pipe for stdin (file descriptor 0)
* A writeable pipe for stdout and stderr (file descriptors 1 and 2)


## In and Out

In  a simple example, lets collect the output of `ps aux`:

```rust
use std::io::Command;

fn main() {
    // Spawn a process, wait for it to finish, and collect it's output
    let the_output = Command::new("ps").arg("aux").output()
        .ok().expect("Failed to execute.");
    // Encode the resulting data.
    let encoded = String::from_utf8_lossy(the_output.output.as_slice());
    print!("{}", encoded);
}
```

It should be noted that this is a blocking call, meaning the current task will halt until the completion of the process. This is acceptable for simple calls to the underlying operating system. `.output()` will handle all the tasks related to piping and spawning for you.

If you're dealing with multiple arguments, you can pass a slice, like so:

```rust
let the_output = Command::new("ps").args(["a", "u", "x"]).output()
    .ok().expect("Failed to execute.");
```

## Spawning and managing the Children

Waiting for the command to **completely** return is kind of lame. What would be better some way to keep track of the process and communicate with it.

```rust
fn spawn(&self) -> IoResult<Process>
```

The [`Process`](http://doc.rust-lang.org/std/io/process/struct.Process.html) type returned by `.spawn()` does just this.

```rust
use std::io::Command;

fn main() {
    // Spawn a process. Do not wait for it to return.
    // Process should be mutable if we want to signal it later.
    let mut the_process = Command::new("curl")
        .arg("http://www.hoverbear.org")
        .spawn().ok().expect("Failed to execute.");
    // Do things with `the_process`
}
```

We can get the [PID](http://doc.rust-lang.org/std/io/process/struct.Process.html#method.id) of the child:

```rust
// Get the PID of the process.
println!("The PID is: {}", the_process.id());
```

Or [signal](http://doc.rust-lang.org/std/io/process/struct.Process.html#method.signal) the process:

```rust
// Signal the process.
// 0 is interpreted as a poll check.
match the_process.signal(0) {
    Ok(_)  => println!("Process still alive!"),
    Err(_) => println!("Process dead.")
}
```

*Note*: `.signal_exit()` and `.signal_kill()` are also available.

[Wait](http://doc.rust-lang.org/std/io/process/struct.Process.html#method.wait) for the process before returning, receiving it's status:

```rust
// Wait for the process to exit.
match the_process.wait() {
    Ok(status) => println!("Finished, status of {}", status),
    Err(e)     => println!("Failed, error: {}", e)
}
```

*Gotcha*: Some processes will not exit until you drain their STDOUT.

Retrieve STDOUT, interacting with it like any [Reader](http://doc.rust-lang.org/std/io/trait.Reader.html):

```rust
// Get a Pipestream, which implements the Reader trait.
let the_stdout_stream = the_process.stdout.as_mut()
    .expect("Couldn't get mutable Pipestream.");
// Drain it into a &mut [u8].
let the_stdout = the_stdout_stream.read_to_end()
    .expect("Couldn't read from Pipestream.");

```

Pipe into STDIN, also, [wait for output](http://doc.rust-lang.org/std/io/process/struct.Process.html#method.wait_with_output) and exit:

```rust
use std::io::Command;

fn main() {
    let mut the_process = Command::new("grep").arg("foo")
        .spawn().ok().expect("Failed to execute.");
    // Get a Pipestream which implements the writer trait.
    // Scope, to ensure the borrow ends.
    let _ = {
        let the_stdin_stream = the_process.stdin.as_mut()
            .expect("Couldn't get mutable Pipestream.");
        // Write to it in binary.
        the_stdin_stream.write_int(123456)
            .ok().expect("Couldn't write to stream.");
        the_stdin_stream.write(b"Foo this, foo that!")
            .ok().expect("Couldn't write to stream.");
        // Flush the output so it ends.
        the_stdin_stream.flush()
            .ok().expect("Couldn't flush the stream.");
    };
    // Wait on output.
    match the_process.wait_with_output() {
        Ok(out)    => print!("{}", out.output.into_ascii()
                          .into_string()),
        Err(error) => print!("{}", error)
    }
}
```

> Rust's borrow check ensures that the process cannot be closed until it is safe to.

Without the scope, the lifetime of the `the_stdin_stream` would still exist when we try to call `the_process.wait_with_output()`. If it was the case that this wasn't tracked, it's possible that `the_stdin_stream` might be used even after the process is closed, something unsafe. We use a scope to limit the lifetime of `the_stdin_stream`, a function could also accomplish this. [More info on lifetimes.](http://doc.rust-lang.org/guide-lifetimes.html)

## Init's Perspective

An init system concerned about more then just the output of a process. It's concerned about the entire lifetime, which user ID runs it, what kind of ENV is exposed to it, what other processes depend on it, and where its STDOUT and STDERR go. So what would a full call to `Command` look like for an init system?

Lets say we want to spawn `curl`, a very long running process, and map it's STDOUT and STDERR to files. We'll also explicitly declare which user and group it should run as, as well as it's CWD and ENV variables.

In it's simplest form:

```rust
extern crate native;
extern crate rustrt;

use std::io::{process, Command};
use native::io::file;
use rustrt::rtio;

fn main() {
    // Open a stdout file. Note this is using the native runtime.
    // The native runtime will allow us to retrieve a file descriptor.
    let stdout_file = file::open(&"stdout_log".to_c_str(),
                                 rtio::Open,
                                 rtio::ReadWrite)
        .ok().expect("Couldn't open STDOUT file.");
    // The same with stderr.
    let stderr_file = file::open(&"stderr_log".to_c_str(),
                                 rtio::Open,
                                 rtio::ReadWrite)
        .ok().expect("Couldn't open STDERR file.");
    // Generate the process very explicitly.
    let mut the_process = Command::new("curl")
        // Slice of arguments.
        .args(["hoverbear.org"])
        // Set User/Group.
        .uid(1000) // Don't know it? Check that user's $UID
        .gid(1000)
        // Set STDOUT
        .stdout(process::InheritFd(stdout_file.fd()))
        // Set STDERR
        .stderr(process::InheritFd(stderr_file.fd()))
        // Set the CWD.
        .cwd(&Path::new("/home/hoverbear"))
        // Set ENV variables.
        .env("IS_EXAMPLE", "true")
        // Or remove ENV variables.
        .env_remove("PRIVATE_VARIABLE")
        // Spawn
        .spawn().ok().expect("Failed to execute");
    // ...
    // Do stuff
    // ...

    // Wait for the process.
    let the_status = the_process.wait()
        .ok().expect("Couldn't wait for process.");
    // Output some exit information.
    match the_status {
        process::ExitStatus(x) => println!("Exited with status {}", x),
        process::ExitSignal(x) => println!("Exited from signal {}", x)
    };
}
```

An init system often tracks many processes, how could you use the above code in a setting where multiple processes are needed? How could we utilize various constructs to monitor and augment the capabilities of a system?

This is only the humble beginning.
