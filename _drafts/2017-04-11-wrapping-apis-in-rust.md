---
layout: post
title: "Wrapping APIs in Rust"

image: /assets/images/2017/04/wrap.jpg
image-credit: "Annie Spratt"

tags:
  - Rust
  - Tutorials
---

Modern applications often interface with external services through RESTful APIs. Examples of this include everything from telephony like [Twilio](http://twilio.com/) to infrastructure like [DigitalOcean](http://digitalocean.com/). In most cases these services provide an HTTP REST API, though there are exceptions such as mailers which sometimes use SMTP.

It's rather common for these services to offer official wrappers for some popular programming languages, and often there are many unofficial wrappers of varying quality. Digital Ocean, for example, offers official Ruby and Go wrappers [here](https://developers.digitalocean.com/libraries/). In languages without a wrapper, interacting with these services can involve some extra work.

It can be the case that dealing with an API in an ad-hoc manner results in as much work (and pain) as just building a proper wrapper around the API. Even if you only need a small portion of the functionality it's quite likely that later on you'll want to reach for another piece of the API, or perhaps another contributor will. The lesson? Invest in the foundation and future work will be easier.

So how do we go about building a wrapper for an API? What should we keep in mind? What design patterns should we use? How do we make it usable?

For this article we'll be playing with DigitalOcean's API because I think it's quite nice, and I'd like a Rust wrapper for it. You can choose any you want, if you're stuck deciding why not try Twilio?

Let's dive in.

## Exploration

The first step to building any API wrapper is to actually explore the API itself. Most APIs have different semantics and patterns, so working with DigitalOcean's API will be different than interacting with Amazon's API, despite the fact that some of the things they do will be similar. Most services provide some form of API documentation like [this](https://developers.digitalocean.com/documentation/v2/) or like [this](https://www.twilio.com/docs/api/rest).

Give it a read. Not just a cursory read, a real go through. Make yourself familiar with how things work. Pay attention to common arguments or return values, for example DigitalOcean returns the same format for all paginated endpoints. Most importantly, **pull out `curl` and try it**.

Before going further, make sure you can answer the following questions:

* What format(s) does the API accept and return?
    + JSON? XML? YAML?
* How is authentication handled?
    + Bearer tokens? Cookies? Query parameters?
* Is there any common parameters?
    + `per_page` on lists? Search query formats?
* How are errors returned?
    + HTTP Status codes? In the response body?
* Is there rate limiting?
    + How can you track it? What is the penalty?

With these answers in our pocket we can start working on planning our code.

### Exploration: DigitalOcean

For DigitalOcean, the following answers exist:

* The request and response format is JSON. Some arguments (such as `/domains/foo.com`) are done via URL segments where appropriate.
* Bearer tokens are used, the token itself is generated and obtained from the control panel.
* Paginated endpoints use `per_page` as a query parameter, with a limit of 200.
* Errors are returned via HTTP Status Codes.
* There is a 5,000 request per hour rate limit. This is trackable via headers.
* Once the rate limit is reached a `429 Too Many Requests` status is returned on all requests.
* The rate limit is a sliding window.

The rate limit for DigitalOcean is quite generous and there is no penalty beyond failed requests (and hitting the rate limit would be an error anyways). Tracking when more requests can be allowed would be difficult anyways since it works via a sliding window. In this case there is no need to track the rate limiting internally, it is better to just return an error variant on API calls reporting that the limit has been reached, and allow the consumer to decide how to act on this.

Another thing that the DigitalOcean API has is an idea of an `Action`, which has the same payload but may be applied to different things, such as a droplet or an image. Instead of creating a seperate `DropletAction` and `ImageAction`, we can just recreate a common `Action`.

## Planning

Unlike executables which are primarily intended to be executed, APIs are primarily intended to be **consumed**. This means when designing our crate we should consider how it feels to use the crate, and whether it feels natural. Exposing an awkward API will only frustrate us and our users.

In general ask yourself: "How can I make this wrapper feel idiomatic...

* ...to the language?"
* ...to the API that exists?"

When an API exposes something like `/user/galleries/12345/photo/54321` and a wrapper exposes `fetch_gallery_photo(54321, 12345)` it can feel quite strange, and the API documentation no longer feels very useful. Instead, the user is forced to utilize the wrapper documentation. Why not have the them call `Gallery::get(12345).photo(54321)` or something similar? At least then they'll be able to have a mental model about how the wrapper maps to the API itself.

Consider also what your API calls will return. Rust's type system, along with `serde`, gives us a very nice way to handle (de)serialization and transformation, so there is no reason to return raw JSON when we could be returning structured types. A call to `/domains/foo.com` can return `Domain { name: "foo.com", ttl: 1800, zone_file: "..." }` almost as easily as the raw representation, and the structure is much more useful.

How are you going to handle parameters to calls? Are you going to make them part of the function arguments? Or ask the consumer to pass a structure? Or are you going to provide a builder pattern? **Choose one and be consistent.** Once a user is familiar with the basics of one part of your wrapper they should be familiar with the basics of all of it.

Consider as well how you can help *limit* the possibility of invalid requests. It is probably not possible to do `Photos::delete(12345).set_album("Vacation Photos")`, so how do you make sure that doesn't happen?

Finally, when planning out your wrapper try to pick a **simple** and a few **complex** parts of the API to work on first. It's an awful feeling to spend hours scaffolding out all the easy bits of a wrapper then discovering your strategy doesn't work on one of the more hairy corners of the API. Instead, go for the hairy bits first, plan for them. It will save you time later.

### Planning: DigitalOcean

While playing with DigitalOcean's API, I played with `Droplet` (complex), `Domain` (complex), and `Region` (simple). `LoadBalancer` was an unexpectedly complicated part of the API which I didn't plan for.

DigtalOceans API is quite consistent, and most calls can map directly to a scheme like the following:

```rust
GET    /resources                         -> Resource::list()
GET    /resources/resource_id             -> Resource::get(resource_id)
GET    /resources/resource_id/subresource -> Resource::get(resource_id).subresource(params)
POST   /resources                         -> Resource::create(params)
DELETE /resources/resource_id             -> Resource::delete(resource_id)
```

Since the values returned by DigitalOcean are well structured they painlessly map into Rust types with `serde`.

Most endpoints for the DigitalOcean API can be quite comfortable using scheme where the required parameters are arguments, and optional parameters are provided via builders. This strategy means that the user can't create a request lacking required values, and also doesn't need to provide a `None` or `Some(T)` for each optional. Additionally, it tends to read quite nice.

```rust
// Arguments
Resource::create(required_value, required_value_2, None, None)
// Builder
Resource::create(required_value, required_value_2)
    .optional_value(true)
    .optional_value_2("String")
```

There are some potential problem points with this methid, such as actions like `LoadBalancer::get(12345).add_forwarding_rules([...])` which accepts an array of `ForwardingRule`. Each item of this array would have 4 required arguments, and 2 optional arguments. In this case we can define a `ForwardingRule` structure and implement `From<(String, usize, String, usize)>`, `From<(String, usize, String, usize, String)>`, and `From<(String, usize, String, usize, String, bool)>` on that structure. Then, we can write `add_forwarding_rules(mut self, vals: Vec<F>) where F: Into<ForwardingRule>` and accept any of these. (Shout out to [Skade](https://github.com/skade/) for this idea!)

## Sketching

Sketching out how you want your API to *feel* is a useful strategy for understanding both your own goals and those of your users. Sit down and write some examples of how your library should be used. Make them minimal, but still complete enough to get the right idea. Be careful not to fool yourself though. Some things that look totally reasonable don't actually work when you get down to the implementation stage. Consider this:

```rust
use digitalocean::DigitalOcean;
let client = DigitalOcean::new("apikey");
// Get a list of droplets.
let droplets = client.droplets()
    .unwrap();
// Find the droplet we want.
let choice = droplets.iter().find(|v| v.name == "webhost")
    .unwrap();
// Delete it.
client.droplets().delete(choice.id)
    .unwrap();
```

What about this API idea doesn't work? Think about when the API requests are made. 

* `client.droplets()` must immediately return a `Vec<Droplet>`, so how do you implement `client.droplets().delete(foo)` without having it make two (or more) API calls?
* If `client.droplets()` returns a `Vec<Droplet>` this means you'd need to `impl DeleteById for Vec<Droplet>` or something similar. This will be both hard to find in the documentation, and possibly confusing to users. It might even conflict with an existing method!

This is why many APIs which make network calls will use a `resolve()` or `execute()` function to actually make the call. Here is another example which does the same thing in a different way:

```rust
use digitalocean::{Droplet, DigitalOcean};
let client = DigitalOcean::new("apikey");
// Get a list of droplets.
let action = Droplet::list();
let droplets = client.execute(action)
    .unwrap();
// Find the droplet we want.
let choice = droplets.iter().find(|v| v.name == "webhost")
    .unwrap();
// Delete it.
client.execute(Droplet::delete(choice.id))
    .unwrap();
```

Is there anything about this API idea which doesn't work? I haven't found one yet! Don't be afraid to look at examples for similar APIs in other languages, or for other services. Sometimes it's a huge help.

Having a small set of examples which you'd like to be compatible with your API is extremely valuable. They can even be your first tests. Rust lets us do this easily by having them in our `examples/` directory. Not only can you try using them (as a consumer of your library) at any time with `cargo run --example my_example`, but they also are compiled during `cargo test` executions to help keep you honest.

## Structure

One of the biggest favors we can do for ourselves in this project is to build a flexible, powerful core. Adding or removing new endpoints and/or functionality should be as simple as possible. Part of the reason we choose both simple *and* complex parts of the API to start with is that we don't go ahead and spend a bunch of time building a foundation which can only handles certain bits of the functionality we need.

Another consideration to keep in mind is how tightly we want to couple to certain dependencies. For example, `serde` is broadly used (de)serialization crate which is relatively unintrusive, and `serde_json` is very robust with JSON. It's reasonably safe to couple tightly to `serde` since it is primarily used internally, the consumer only might encouter it when dealing with `Serialize`/`Deserialize` bounds on some parameters. On the other hand coupling to a specific HTTP client may cause pain in the future. What if in a few months we want to move from `reqwest` to `hyper`? Or migrate from syncronous to asyncronous?

The existence of feature flags means that we could even structure our API such that either `reqwest` or `hyper` could be used without much pain... If we structure it right.

A crate interfacing with a REST service can have the following main components:

* A 'Request' structure which represents an unexecuted API call.
* A 'Client' which holds the HTTP client as well as authentication details.
* An 'Error' type representing the various expected and unexpected errors.
* A number of types that relate to the specific service. (Eg. `Domain`, `Droplet`, `SshKey`)

The Client and the Requests being separate represents a separation of concerns: Requests represent the *action* desired, and Clients know how to *execute* that action. This is both for safety (it makes it much harder to accidently dump your API token, for example) and for simplicity. We need a `Droplet` structure anyways, keeping its concerns isolated in as few places as possible is a boon for understand, maintenance, and later feature additions.

Taking a strategy like this creates a structure like so:

```
.
├── Cargo.lock
├── Cargo.toml
├── examples
│   ├── account.rs
│   └── ...
├── rustfmt.toml
├── src
│   ├── api
│   │   ├── account.rs
│   │   ├── mod.rs
│   │   └── ...
│   ├── client
│   │   ├── mod.rs
│   │   └── reqwest.rs
│   ├── error.rs
│   ├── lib.rs
│   ├── method.rs
│   ├── prelude.rs
│   └── request.rs
└── tests
    ├── account.rs
    └── ...
```

Let's take a brief spin over the implementations of the different components. This isn't the only way to accomplish things, **nor is it necessarily the best**. It's just a way that works.

### The `Request`

Any sufficiently complex requirements will inevitably produce pieces of complex code. Figuring out where to focus this complexity and how to manage it is a key part in building understandable systems. In the case of my `DigitalOcean` crate the `Request` structure holds most of the complexity.


### The `Client`

I tried to keep my `Client` fairly simple. It's just a structure containing an HTTP Client (in this case `reqwest::Client`) as well as an API key. There are only a few functions attached to the implementation of this structure, split between `src/lib.rs` and `src/client/mod.rs` (HTTP client specific code).

```rust
pub fn new<T: Into<String>>(token: T) -> Result<Self> {}
pub fn execute<A, V>(&self, request: Request<A, V>) -> Result<V> {}
fn fetch(&self, dispatch: RequestBuilder) -> Result<Response> {}

pub fn get<V>(&self, request: Request<Get, V>) -> Result<V> {}
pub fn list<V>(&self, request: Request<List, Vec<V>>) -> Result<Vec<V>> {}
pub fn delete<V>(&self, request: Request<Delete, V>) -> Result<()> {}
pub fn post<V>(&self, request: Request<Create, V>) -> Result<V> {}
pub fn put<V>(&self, request: Request<Update, V>) -> Result<V> {}
```

