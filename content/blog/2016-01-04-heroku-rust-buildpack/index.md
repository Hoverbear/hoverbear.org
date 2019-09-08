+++
title = "A Rust Heroku Buildpack"
aliases = ["2016/01/04/Heroku-Rust-Buildpack/"]
layout = "blog/single.html"
[taxonomies]
tags = [
  "Rust",
]
[extra]
image = "cover.jpg"
+++

I'm happy to introduce the first stable version of my Rust Heroku Buildpack!

> Just looking to get your hands dirty? Look [**here**](https://github.com/Hoverbear/heroku-buildpack-rust).

The project was a really interesting learning experience about how [Heroku](http://heroku.com/) does things, on `bash` scripting, and about [`multirust`](https://github.com/brson/multirust/), which I'd not used before but now am quite a fan of! (I previously just `rustup`'d the newest nightly every few days.)

<!-- more -->

### Features

* Cached `multirust`, Rust toolchain.
* Caching of previous build artifacts to (potentially dramatically) speed up similar builds.
* Configurable version selection inside of the Cargo.toml.

It's unit tested using Heroku's official [testrunner](https://github.com/heroku/heroku-buildpack-testrunner) every commit (using [homu](http://homu.io/)) and includes a `Makefile` which executes a docker based test locally.

### Development Story

I am a huge fan of Heroku, they're were I hosted my first web app, they are where [Gathering Our Voices](http://gatheringourvoices.bcaafc.com/) hosted our website for two years, and I have several friends who work there. While I was in San Fransisco for our [`raft-rs` meetup](/2015/08/27/meetup/) they even invited me to come visit and meet some of their team.

There was, however, one sore point with Heroku for me: There were no Rust buildpacks I was happy with! There was [emk's](https://github.com/emk/heroku-buildpack-rust) and [chrisumbel's](https://github.com/chrisumbel/heroku-buildpack-rust) but I wasn't particularly happy with either. There wasn't a ton of flexibility with them and they were both only manually tested with `vagrant` VMs. The last update to either was in March, which was still around the time when Rust was rapidly changing and maturing. (Though, it still is, but more conservatively!)

Originally my plan had been to issue a PR to one of them, but by the time I started digging into how things worked I realized **I wanted to make my own buildpack**. So I did. At first I used `rustup` and tried to handle detecting when to update myself, but eventually realized `multirust` was a more straightforward way to go.

I made the mistake of starting it right before both exams and the holidays, so things went slower than I anticipated. Along the way I got to learn several neat lessons which I've shared below. I'm looking forward to playing more with Rust on Heroku and would some day like to see `raft-rs` based applications on their infrastructure.

> A special thanks to my friends at Heroku, Peter and Joe, for helping me work out a few kinks and showing me the test-runner (which showed me the `cedar` docker images as well!)

### Lessons Learned

* **Rust has no posted version strings for `nightly` and `beta`**, unlike stable which you can get the current versions with `curl https://static.rust-lang.org/dist/channel-rust-stable`, you cannot use a similar method to detect for `beta` and `nightly`. While I was using `rustup` at one point I resorted to using `curl -s https://doc.rust-lang.org/$RUSTC_CHANNEL/index.html | grep -hE "class=\"hash" | grep -ohE "\w{9}"` to detect the version! I didn't like that, it was dirty.

* **Heroku doesn't let buildpacks do anything more than applications really.** Really, thinking about it, this makes sense, but I was initially really surprised that I couldn't (easily) use tools like `apt-get` to fetch packages.

* **`grep`'s options are vaster in number than I first realized.** I love `grep` and use it with regexs all the time, but in my exploration I actually found some really interesting flags, including one that `null`s out newlines for multiline matching. Crazy stuff!

* **`multirust` doesn't seem to allow you to configure where it puts the `.multirust` directory.** While I tried several promising sounding flags (`--prefix`, `--destdir`) I didn't find anything of the sort. I ended up just setting `$HOME` myself, but I don't think this is the best idea.
