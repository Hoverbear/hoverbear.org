+++
title = "Instrumenting Axum projects"
description = "Fitting the pieces together for pleasant errors and logs."
template =  "blog/single.html"

[taxonomies]
tags = [
    "Rust",
]

[extra.image]
path = "cover.jpg"
colocated = true
photographer = "Cristiano Firmani"
source = "https://unsplash.com/photos/tmTidmpILWw"
+++

Recently I was helping someone get bootstrapped on their Axum project, and they were getting a bit frustrated with the lack of context about the goings on in their application.
While Axum and it's ecosystem are well instrumented, by default most of it is not very well surfaced for beginners.
It can be a bit intimidating figuring out how to put the pieces together and use them.

<!-- more -->

Once we set up [`tracing`] and [`color_eyre`] our logging and errors went from looking like this:

```
Listening on [::]:8080
Got an error request on `/error`
Got request for `/favicon.ico`, but no route was found.
Got a homepage request on `/`
```

To something with a little bit more context:

```
 INFO Listening on [::]:8080
 INFO request:get_error: Got an error request uri=/error method=GET source=::1
ERROR request: 
   0: Whoopsies

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ SPANTRACE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   0: demo::routes::get_error
      at src/routes.rs:11
   1: demo::trace_layer::request with uri=/error method=GET source=::1
      at src/trace_layer.rs:24

Backtrace omitted. Run with RUST_BACKTRACE=1 environment variable to display it.
Run with RUST_BACKTRACE=full to include source snippets. uri=/error method=GET source=::1
 INFO request:get_home: Got a homepage request uri=/ method=GET source=::1
 INFO request:fallback_404: Got request, but no route was found. uri=/favicon.ico method=GET source=::1
```

While this isn't a complete and fully mature solution suitable for an industrial application, it is a good starting point for them that smoothly evolve into something more mature.

Often the first place I start with a binary project is the command line interface, so we'll start there.

## Making instrumentation tuneable

Instrumentation can have many knobs, this project used [`clap`], so we took the existing `Cli` struct and added an `instrumentation` field:

```rust
// src/cli/mod.rs
mod instrumentation;
mod logger;

use clap::Parser;
use std::net::{IpAddr, Ipv6Addr, SocketAddr};

#[derive(Parser)]
pub(crate) struct Cli {
    #[clap(long, env = "DEMO_BIND", default_value_t = SocketAddr::new(
        IpAddr::V6(Ipv6Addr::new(0, 0, 0, 0, 0, 0, 0, 0)), 8080)
    )]
    pub(crate) bind: SocketAddr,

    #[clap(flatten)]
    pub(crate) instrumentation: instrumentation::Instrumentation,
}
```

Using `#[clap(flatten)]` here means we can define all our instrumentation options in a separate struct, while still appearing in the `--help` as one might expect:

```
❯ cargo run -- --help
    Finished dev [unoptimized + debuginfo] target(s) in 0.04s
     Running `target/debug/demo --help`
Usage: demo [OPTIONS]

Options:
      --bind <BIND>
          [env: DEMO_BIND=]
          [default: [::]:8080]

  -v, --verbose...
          Enable debug logs, -vv for trace
          
          [env: DEMO_VERBOSITY=]

      --logger <LOGGER>
          Which logger to use
          
          [env: DEMO_LOGGER=]
          [default: compact]
          [possible values: compact, full, pretty, json]

      --log-directive [<LOG_DIRECTIVES>...]
          Tracing directives
          
          See https://docs.rs/tracing-subscriber/latest/tracing_subscriber/filter/struct.EnvFilter.html#directives
          
          [env: DEMO_LOG_DIRECTIVES=]

  -h, --help
          Print help (see a summary with '-h')
```

Tracing offers use the choice of several built in logging styles, or even our own logging style if we so choose!
It's quite easy to pass on this choice to the user, though we do need to create `Logger` enum to represent that choice:

```rust
// src/cli/logger.rs
#[derive(Clone, Default, Debug, clap::ValueEnum)]
pub(crate) enum Logger {
    #[default]
    Compact,
    Full,
    Pretty,
    Json,
}

impl std::fmt::Display for Logger {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let logger = match self {
            Logger::Compact => "compact",
            Logger::Full => "full",
            Logger::Pretty => "pretty",
            Logger::Json => "json",
        };
        write!(f, "{}", logger)
    }
}
```

The `Logger` can then get used in in our `Instrumentation` struct, which we'll build up over the next few code blocks:

```rust
// src/cli/instrumentation.rs
use color_eyre::eyre::WrapErr;
use std::{error::Error, io::IsTerminal};
use tracing::Subscriber;
use tracing_subscriber::{
    filter::Directive,
    layer::{Layer, SubscriberExt},
    registry::LookupSpan,
    util::SubscriberInitExt,
    EnvFilter,
};

use super::logger::Logger;

#[derive(clap::Args, Debug, Default)]
pub(crate) struct Instrumentation {
    /// Enable debug logs, -vv for trace
    #[clap(
        short = 'v',
        env = "DEMO_VERBOSITY",
        long, action = clap::ArgAction::Count,
        global = true
    )]
    pub verbose: u8,
    /// Which logger to use
    #[clap(
        long,
        env = "DEMO_LOGGER",
        default_value_t = Default::default(),
        global = true
    )]
    pub(crate) logger: Logger,
    /// Tracing directives
    ///
    /// See https://docs.rs/tracing-subscriber/latest/tracing_subscriber/filter/struct.EnvFilter.html#directives
    #[clap(long = "log-directive", global = true, env = "DEMO_LOG_DIRECTIVES", value_delimiter = ',', num_args = 0..)]
    pub(crate) log_directives: Vec<Directive>,
}

impl Instrumentation {
    pub(crate) fn log_level(&self) -> String {
        match self.verbose {
            0 => "info",
            1 => "debug",
            _ => "trace",
        }
        .to_string()
    }
    // (continued below)
}
```

This interface offers users the ability to specify 'traditional' verbosity options such as `-v` or, my favorite, `-vvvvvvv` through the use of [`clap::ArgAction::Count`].
It also permits the use of more [`tracing`]-specific options like the `Logger` we created above, or the option of any number of [`tracing_subscriber::filter::Directive`]. We'll explore those a bit together once we get things running.

We can then attach some functions to this struct that set up a [`Registry`][`tracing_subscriber::registry::Registry`] which stores [span][`tracing::span`] data, such as the data defined in [`#[tracing::instrument]`][`tracing::instrument`] calls.
In a `setup()` function we'll build a [`Registry`][`tracing_subscriber::registry::Registry`] and compose it with several layers, including a [`ErrorLayer`][`tracing_error::ErrorLayer`] and an [`EnvFilter`][`tracing_subscriber::filter::EnvFilter`] layer we configure from the knobs made available in the `Cli` struct (as well as some conventional environment variables):

```rust
impl Instrumentation {
    // (continued)
    pub(crate) fn setup(&self) -> color_eyre::Result<()> {
        let filter_layer = self.filter_layer()?;

        let registry = tracing_subscriber::registry()
            .with(filter_layer)
            .with(tracing_error::ErrorLayer::default());

        // `try_init` called inside `match` since `with` changes the type
        match self.logger {
            Logger::Compact => {
                registry.with(self.fmt_layer_compact()).try_init()?
            }
            Logger::Full => {
                registry.with(self.fmt_layer_full()).try_init()?
            }
            Logger::Pretty => {
                registry.with(self.fmt_layer_pretty()).try_init()?
            }
            Logger::Json => {
                registry.with(self.fmt_layer_json()).try_init()?
            }
        }

        Ok(())
    }

    pub(crate) fn filter_layer(&self) -> color_eyre::Result<EnvFilter> {
        let mut filter_layer = match EnvFilter::try_from_default_env() {
            Ok(layer) => layer,
            Err(e) => {
                // Catch a parse error and report it, ignore a missing env
                if let Some(source) = e.source() {
                    match source.downcast_ref::<std::env::VarError>() {
                        Some(std::env::VarError::NotPresent) => (),
                        _ => return Err(e).wrap_err_with(|| "parsing RUST_LOG directives"),
                    }
                }
                // If the `--log-directive` is specified, don't set a default
                if self.log_directives.is_empty() {
                    EnvFilter::try_new(&format!(
                        "{}={}",
                        env!("CARGO_PKG_NAME").replace('-', "_"),
                        self.log_level()
                    ))?
                } else {
                    EnvFilter::try_new("")?
                }
            }
        };

        for directive in &self.log_directives {
            let directive_clone = directive.clone();
            filter_layer = filter_layer.add_directive(directive_clone);
        }

        Ok(filter_layer)
    }
    // (continued below)
}
```

Then we can go ahead and define the various format layers, along with any [customization](https://docs.rs/tracing-subscriber/latest/tracing_subscriber/fmt/struct.Layer.html#) we wanted to do.

```rust
impl Instrumentation {
    // (continued)
    pub(crate) fn fmt_layer_full<S>(&self) -> impl Layer<S>
    where
        S: Subscriber + for<'span> LookupSpan<'span>,
    {
        tracing_subscriber::fmt::Layer::new()
            .with_ansi(std::io::stderr().is_terminal())
            .with_writer(std::io::stderr)
    }

    pub(crate) fn fmt_layer_pretty<S>(&self) -> impl Layer<S>
    where
        S: Subscriber + for<'span> LookupSpan<'span>,
    {
        tracing_subscriber::fmt::Layer::new()
            .with_ansi(std::io::stderr().is_terminal())
            .with_writer(std::io::stderr)
            .pretty()
    }

    pub(crate) fn fmt_layer_json<S>(&self) -> impl Layer<S>
    where
        S: Subscriber + for<'span> LookupSpan<'span>,
    {
        tracing_subscriber::fmt::Layer::new()
            .with_ansi(std::io::stderr().is_terminal())
            .with_writer(std::io::stderr)
            .json()
    }

    pub(crate) fn fmt_layer_compact<S>(&self) -> impl Layer<S>
    where
        S: Subscriber + for<'span> LookupSpan<'span>,
    {
        tracing_subscriber::fmt::Layer::new()
            .with_ansi(std::io::stderr().is_terminal())
            .with_writer(std::io::stderr)
            .compact()
            .without_time()
            .with_target(false)
            .with_thread_ids(false)
            .with_thread_names(false)
            .with_file(false)
            .with_line_number(false)
    }
}
```

Later, your project may choose to integrate something like [`tracing_opentelemetry`] and route that data to a service like [Honeycomb].

# Building up `Error`s

[`axum`] allows us to define routes that can return errors, if that error implements [`axum::response::IntoResponse`]:

```rust
async fn some_route() -> Result<impl IntoResponse, SomeError> {
    Ok("I work ok!")
}
```

Unfortunately, this does not work out of the box with [`eyre::Report`].
It's also forbidden for us (as `demo`) to implement [`IntoResponse`][`axum::response::IntoResponse`] for [`Report`][`eyre::Report`] due to the [Orphan Rule](https://rust-lang.github.io/chalk/book/clauses/coherence.html), so we must create a wrapper. While we do that, we might as well create a crate-specific `DemoError` as well, which can be later used to define user-facing error messages and status codes.

```rust
// src/error.rs
use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
};

pub type Result<T, E = Report> = color_eyre::Result<T, E>;
// A generic error report
// Produced via `Err(some_err).wrap_err("Some context")`
// or `Err(color_eyre::eyre::Report::new(SomeError))`
pub struct Report(color_eyre::Report);

impl std::fmt::Debug for Report {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        self.0.fmt(f)
    }
}

impl<E> From<E> for Report
where
    E: Into<color_eyre::Report>,
{
    fn from(err: E) -> Self {
        Self(err.into())
    }
}

// Tell axum how to convert `Report` into a response.
impl IntoResponse for Report {
    fn into_response(self) -> Response {
        let err = self.0;
        let err_string = format!("{err:?}");

        tracing::error!("{err_string}");

        if let Some(err) = err.downcast_ref::<DemoError>() {
            return err.response()
        }

        // Fallback
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            "Something went wrong".to_string(),
        )
            .into_response()
    }
}

#[derive(thiserror::Error, Debug)]
pub(crate) enum DemoError {
    #[error("A spooky thing happened")]
    Spooky,
}

// Tell axum how to convert `DemoError` into a response.
impl DemoError {
    fn response(&self) -> Response {
        match self {
            Self::Spooky => (
                StatusCode::IM_A_TEAPOT,
                "A user-facing message about a Spooky".to_string(),
            )
                .into_response(),
        }
    }
}
```

Now we can use that new `Result` in our routes, and return errors either ad-hoc via [`eyre::eyre`], or structured through the error type we created with [`thiserror`].

> This is also a good opportunity to decorate your routes with a [`tracing::instrument`] attribute. 
>
> Consider using `skip_all` and explicitly defining any fields if you are dealing complex route arguments!
> Eg. `#[tracing::instrument(skip_all, fields(uid = context.user.uid))]`.

```rust
use crate::error::Result;
use axum::response::IntoResponse;
use color_eyre::eyre::eyre;

#[tracing::instrument]
pub(crate) async fn get_error() -> Result<impl IntoResponse> {
    tracing::info!("Got an error request");

    // Bang!!!
    Err(eyre!("Whoopsies"))?;

    Ok(())
}
```

At the start, and during prototyping, you can use [`eyre::eyre`] to write easy ad-hoc errors.
As the application grows, you'll be able to work with [`thiserror`] and use [`downcast_ref`](https://docs.rs/eyre/latest/eyre/struct.Report.html#method.downcast_ref) (like we did in the `instrumentation.rs` code) and other tools available in [`eyre::Report`] to respond with a more structured and informative messages to the web browser.


```rust
use crate::error::Result;
use axum::response::IntoResponse;

// After adding a `Spooky` variant to `DemoError` in `src/error.rs`:
//
// #[derive(thiserror::Error, Debug)]
// enum DemoError {
//     #[error("A spooky thing happened")]
//     Spooky
// }

#[tracing::instrument]
pub(crate) async fn get_demo_error() -> Result<impl IntoResponse> {
    tracing::info!("Got an error request");

    // Bang!!!
    Err(DemoError::Spooky)?;

    Ok(())
}
```

## Putting the pieces together

After painting our user interface and performing the ritualistic type dancing, it's finally time to update `main()` with the code to get everything working.

At the very top of `main()` we want to install [`color_eyre`]'s error hooks, so that any errors after that are fully styled and integrated.
After that, we can call `setup()` on the `Instrumentation` instance created by [`clap`] to initialize tracing.

In order to add the appropriate spans to requests, [`tower_http::trace::TraceLayer`] should be added to the [`axum::routing::Router`]:

```rust
// src/main.rs
mod cli;
mod error;
mod routes;
mod trace_layer;

use crate::{cli::Cli, error::Result};
use axum::routing::get;
use clap::Parser;
use std::{io::IsTerminal, net::SocketAddr, process::ExitCode};
use tower_http::trace::TraceLayer;

#[tokio::main]
async fn main() -> Result<ExitCode> {
    color_eyre::config::HookBuilder::default()
        .theme(if !std::io::stderr().is_terminal() {
            // Don't attempt color
            color_eyre::config::Theme::new()
        } else {
            color_eyre::config::Theme::dark()
        })
        .install()?;

    let cli = Cli::parse();
    cli.instrumentation.setup()?;

    let trace_layer = TraceLayer::new_for_http()
        .make_span_with(trace_layer::trace_layer_make_span_with)
        .on_request(trace_layer::trace_layer_on_request)
        .on_response(trace_layer::trace_layer_on_response);

    let app = axum::Router::new()
        .route("/", get(routes::get_home))
        .route("/errors", get(routes::get_error))
        .route("/errors/demo", get(routes::get_demo_error))
        .fallback(routes::fallback_404)
        .layer(trace_layer);

    tracing::info!("Listening on {}", cli.bind);
    axum::Server::bind(&cli.bind)
        .serve(app.into_make_service_with_connect_info::<SocketAddr>())
        .await?;

    Ok(ExitCode::SUCCESS)
}
```

[`TraceLayer`][`tower_http::trace::TraceLayer`] offers opportunities to attach our own functions where we can create spans or emit events.
There exist defaults ([`tower_http::trace::{DefaultMakeSpan, DefaultOnRequest}`][`tower_http::trace`]) which can be modified using a builder API, these have the rather unfortunate quality of being part of the `tower_http` crate, not our own, so because the defaults we configured in the `Instrumentation::filter_layer()` function they won't normally be enabled.

Defining our own functions allows us to build our own base span, as well as ensure these spans are part of our own crate.
If your project opts to use the defaults, consider altering `Instrumentation::filter_layer()` to also set some default for `tower_http`.

```rust
// src/trace_layer.rs
use axum::{body::BoxBody, extract::ConnectInfo, response::Response};
use hyper::{Body, Request};
use std::{net::SocketAddr, time::Duration};
use tracing::Span;

pub(crate) fn trace_layer_make_span_with(request: &Request<Body>) -> Span {
    tracing::error_span!("request",
        uri = %request.uri(),
        method = %request.method(),
        // This is not particularly robust, but suitable for a demo
        // You'll need to change this if you deploy behind a proxy
        // (eg the `X-forwarded-for` header)
        source = request.extensions()
            .get::<ConnectInfo<SocketAddr>>()
            .map(|connect_info|
                tracing::field::display(connect_info.ip().to_string()),
            ).unwrap_or_else(||
                tracing::field::display(String::from("<unknown>"))
            ),
        // Fields must be defined to be used, define them as empty if they populate later
        status = tracing::field::Empty,
        latency = tracing::field::Empty,
    )
}

pub(crate) fn trace_layer_on_request(_request: &Request<Body>, _span: &Span) {
    tracing::trace!("Got request")
}

pub(crate) fn trace_layer_on_response(
    response: &Response<BoxBody>,
    latency: Duration,
    span: &Span,
) {
    span.record(
        "latency",
        tracing::field::display(format!("{}μs", latency.as_micros())),
    );
    span.record("status", tracing::field::display(response.status()));
    tracing::trace!("Responded");
}
```

We can create a few test routes a fallback route, one reporting no error, another reporting an [`eyre::eyre`] based error, and a route reporting a `DemoError`.
Due to our error handling code we can use `DemoError` variants to return specific, user-facing messages and status codes, while more ad-hoc or developer/operator facing errors can be [`eyre::eyre`] based.

```rust
// src/routes.rs
use crate::error::{Result, DemoError};
use axum::response::IntoResponse;
use color_eyre::eyre::eyre;

#[tracing::instrument]
pub(crate) async fn get_home() -> Result<impl IntoResponse> {
    tracing::info!("Got a homepage request");
    Ok("Welcome to my super cute home page")
}

#[tracing::instrument]
pub(crate) async fn get_error() -> Result<impl IntoResponse> {
    tracing::info!("Got an error request");

    Err(eyre!("Whoopsies"))?;

    Ok(())
}

#[tracing::instrument]
pub(crate) async fn get_demo_error() -> Result<impl IntoResponse> {
    tracing::info!("Got an error request");

    Err(DemoError::Spooky)?;

    Ok(())
}

#[tracing::instrument(skip_all)]
pub(crate) async fn fallback_404() -> Result<impl IntoResponse> {
    tracing::info!("Got request, but no route was found.");
    Ok("You failed to find my super cute home page")
}
```

If you're following along you may have run `cargo add` for some of the dependencies above, the specific examples shown utilized the following features and crates:

```toml
# Cargo.toml
[package]
name = "demo"
version = "0.1.0"
edition = "2021"

[dependencies]
axum = "0.6"
clap = { version = "4.3", features = ["derive", "env"] }
color-eyre = { version = "0.6", default-features = false, features = [ "issue-url", "tracing-error", "capture-spantrace", "color-spantrace" ] }
hyper = "0.14"
thiserror = "1"
tokio = { version = "1", features = ["full"] }
tower = "0.4"
tower-http = { version = "0.4", features = ["trace"] }
tracing = "0.1"
tracing-error = "0.2"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
```

One feature you may wish to enable the `track-caller` on [`color-eyre`][`color_eyre`] package, it will show the locations of errors in the output using the [`track_caller`] attribute.
The reported location is not always accurate, but often it's helpful.

# Going for a test run

At this point, we can run our binary and visit the homepage:

```bash
❯ cargo run
    Finished dev [unoptimized + debuginfo] target(s) in 0.05s
     Running `target/debug/demo`
 INFO Listening on [::]:8080
 INFO request:get_home: Got a homepage request uri=/ method=GET source=::1
 INFO request:fallback_404: Got request, but no route was found. uri=/favicon.ico method=GET source=::1
```

We can run the application again with different directives and get some more info from one of the packages, for example [`hyper`] which does the bulk of the HTTP work:

```bash
❯ cargo run -- --logger compact --log-directive demo=trace --log-directive hyper=trace
    Finished dev [unoptimized + debuginfo] target(s) in 0.05s
     Running `target/debug/demo --logger compact --log-directive demo=trace --log-directive hyper=trace`
 INFO Listening on [::]:8080
TRACE Conn::read_head
TRACE received 454 bytes
TRACE parse_headers: Request.parse bytes=454
TRACE parse_headers: Request.parse Complete(454)
DEBUG parsed 12 headers
DEBUG incoming body is empty
TRACE request: Got request uri=/ method=GET source=::1
 INFO request:get_home: Got a homepage request uri=/ method=GET source=::1
TRACE request: Responded uri=/ method=GET source=::1 latency=175μs status=200 OK
TRACE encode_headers: Server::encode status=200, body=Some(Known(34)), req_method=Some(GET)
TRACE sized write, len = 34
TRACE buffer.queue self.len=117 buf.len=34
# ...
```

That's **a lot of output**! We can also use [log directives][`tracing_subscriber::filter::EnvFilter`] to drill down into specific parts of the code, this can be quite useful for debugging. Here we isolate [`hyper`] events to `parse_headers`:

```bash
❯ cargo run -- --log-directive hyper[parse_headers]=trace --log-directive demo=info
    Finished dev [unoptimized + debuginfo] target(s) in 0.05s
     Running `target/debug/demo --log-directive 'hyper[parse_headers]=trace' --log-directive demo=info`
 INFO Listening on [::]:8080
TRACE parse_headers: Request.parse bytes=464
TRACE parse_headers: Request.parse Complete(464)
 INFO request:get_demo_error: Got an error request uri=/error/demo method=GET source=::1
ERROR request: 
   0: A spooky thing happened

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ SPANTRACE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   0: demo::routes::get_demo_error
      at src/routes.rs:20
   1: demo::trace_layer::request with uri=/error/demo method=GET source=::1
      at src/trace_layer.rs:24

Backtrace omitted. Run with RUST_BACKTRACE=1 environment variable to display it.
Run with RUST_BACKTRACE=full to include source snippets. uri=/error/demo method=GET source=::1
```

Or how about only logging requests for a specific URL? We can specify a filter like `demo[request{uri=/}]=trace` and visit several pages, observing we only see logs for the one we filtered for:

```bash
❯ cargo run -- --log-directive demo[request{uri=/}]=trace
   Compiling demo v0.1.0 (/home/ana/git/determinatesystems/axum-with-tracing-and-eyre)
    Finished dev [unoptimized + debuginfo] target(s) in 2.25s
     Running `target/debug/demo --log-directive 'demo[request{uri=/}]=trace'`
TRACE request: Got request uri=/ method=GET source=::1
 INFO request:get_home: Got a homepage request uri=/ method=GET source=::1
TRACE request: Responded uri=/ method=GET source=::1 latency=333μs status=200 OK
```

Of the different logger options, my personal favorite is the [`pretty`][`tracing_subscriber::fmt::format::Pretty`] logger which creates a cozy, human readable experience:

```bash
❯ cargo run -- --logger pretty 
    Finished dev [unoptimized + debuginfo] target(s) in 0.04s
     Running `target/debug/demo --logger pretty`
  2023-07-19T21:56:16.481962Z  INFO demo: Listening on [::]:8080
    at src/main.rs:38

  2023-07-19T21:56:20.084723Z  INFO demo::routes: Got a homepage request
    at src/routes.rs:7
    in demo::routes::get_home
    in demo::trace_layer::request with uri: /, method: GET, source: ::1

  2023-07-19T21:56:20.131037Z  INFO demo::routes: Got request, but no route was found.
    at src/routes.rs:40
    in demo::routes::fallback_404
    in demo::trace_layer::request with uri: /favicon.ico, method: GET, source: ::1
```

The tracing spans also appear in our errors, let's take a look at those. We can observe these errors when we visit the respective `/error` urls:

```bash
❯ cargo run
    Finished dev [unoptimized + debuginfo] target(s) in 0.04s
     Running `target/debug/demo`
 INFO Listening on [::]:8080
 INFO request:get_error: Got an error request uri=/error method=GET source=::1
ERROR request: 
   0: Whoopsies

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ SPANTRACE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   0: demo::routes::get_error
      at src/routes.rs:12
   1: demo::trace_layer::request with uri=/error method=GET source=::1
      at src/trace_layer.rs:24

Backtrace omitted. Run with RUST_BACKTRACE=1 environment variable to display it.
Run with RUST_BACKTRACE=full to include source snippets. uri=/error method=GET source=::1
 INFO request:fallback_404: Got request, but no route was found. uri=/favicon.ico method=GET source=::1
 INFO request:get_demo_error: Got an error request uri=/error/demo method=GET source=::1
ERROR request: 
   0: A spooky thing happened

  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ SPANTRACE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   0: demo::routes::get_demo_error
      at src/routes.rs:27
   1: demo::trace_layer::request with uri=/error/demo method=GET source=::1
      at src/trace_layer.rs:24

Backtrace omitted. Run with RUST_BACKTRACE=1 environment variable to display it.
Run with RUST_BACKTRACE=full to include source snippets. uri=/error/demo method=GET source=::1
 INFO request:fallback_404: Got request, but no route was found. uri=/favicon.ico method=GET source=::1
```

Visiting `/error/demo` we can observe the browser returning `A spooky occured` as we intended.


## Conclusion

The combination of [`thiserror`], [`tracing`], and [`color_eyre`] provides a solid starting point for a budding project. The ability to instrument code with spans, see those spans in errors, then filter based on those spans in logging messages enables greater insight while diagnosing issues and authoring new features. As your project grows, these same tools offer a smooth path to adoption of standards like [OpenTelemetry].

While researching this article I bumped into the really lovely article by [@carlosmv](https://carlosmv.hashnode.dev/adding-logging-and-tracing-to-an-axum-app-rust) about a many of the same ideas! They go in detail about how to use [`tracing_appender`] and some other things which are not covered here, but don't discuss error handling as much. If you want to dig deeper into this topic, that article is a wonderful place to visit after this!

A few years ago I gave [a recorded talk at TremorCon](https://www.youtube.com/watch?v=ZC7fyqshun8) which discussed [`tracing`] and [`color_eyre`], and this article expands on several of the concepts mentioned there.

This article was suggested by my employer and friend, [@grahamc] at [Determinate Systems].

[`axum::response::IntoResponse`]: https://docs.rs/axum/0.6/axum/response/trait.IntoResponse.html
[`axum::routing::Router`]: https://docs.rs/axum/0.6/axum/routing/struct.Router.html
[`axum`]: https://docs.rs/axum/0.6/axum/
[`clap::ArgAction::Count`]: https://docs.rs/clap/4.3/clap/enum.ArgAction.html#variant.Count
[`clap`]: https://docs.rs/clap/4.3/clap/
[`color_eyre`]: https://docs.rs/color-eyre/0.6/color_eyre/
[`eyre::eyre`]: https://docs.rs/eyre/0.6/eyre/macro.eyre.html
[`eyre::Report`]: https://docs.rs/eyre/0.6/eyre/struct.Report.html
[`eyre::Report`]: https://docs.rs/eyre/0.6/eyre/struct.Report.html
[`hyper`]: https://docs.rs/hyper/0.14/hyper/
[`thiserror`]: https://docs.rs/thiserror/1/thiserror/
[`tower_http::trace::TraceLayer`]: https://docs.rs/tower-http/0.4.1/tower_http/trace/struct.TraceLayer.html
[`tower_http::trace`]: https://docs.rs/tower-http/0.4/tower_http/trace/index.html
[`tracing_appender`]: https://docs.rs/tracing-appender/latest/tracing_appender/
[`tracing_error::ErrorLayer`]: https://docs.rs/tracing-error/0.2/tracing_error/struct.ErrorLayer.html
[`tracing_opentelemetry`]: https://docs.rs/tracing-opentelemetry/latest/tracing_opentelemetry/
[`tracing_subscriber::filter::Directive`]: https://docs.rs/tracing-subscriber/0.3/tracing_subscriber/filter/struct.Directive.html
[`tracing_subscriber::filter::EnvFilter`]: https://docs.rs/tracing-subscriber/0.3/tracing_subscriber/filter/struct.EnvFilter.html
[`tracing_subscriber::fmt::format::Pretty`]: https://docs.rs/tracing-subscriber/0.3/tracing_subscriber/fmt/format/struct.Pretty.html
[`tracing_subscriber::registry::Registry`]: https://docs.rs/tracing-subscriber/0.3/tracing_subscriber/registry/struct.Registry.html
[`tracing::instrument`]: https://docs.rs/tracing/0.1/tracing/attr.instrument.html
[`tracing::span`]: https://docs.rs/tracing/latest/tracing/span/index.html
[`tracing`]: https://docs.rs/tracing/0.1/tracing/
[`track_caller`]: https://rustc-dev-guide.rust-lang.org/backend/implicit-caller-location.html
[Honeycomb]: https://www.honeycomb.io/
[OpenTelemetry]: https://opentelemetry.io/
[Determinate Systems]: https://determinate.systems
[@grahamc]: https://github.com/grahamc
