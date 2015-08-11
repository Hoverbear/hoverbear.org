---
layout: post
title: "Why learn Rust?"
---

Okay, so you're tried Rust before. Maybe it was a long time ago, maybe it was just yesterday. Heck, you might even be going *That's the language that uses explicitive symbols for pointers like `@~*&`*. Maybe you hated it, maybe you loved it.

But really, let's be serious. We hear about new languages *every week*, even those of us who don't really follow programming language news. It pops up on Reddit or Hackernews, everyone marvels at it's `features[x]` and how they wish `features[y]` was part of their programming language. A few enterprising individuals try it, report back, and we all go back to languages that make us comfortable. *It's the way it's always been done.* We say to ourselves.

> So, why spend time learning Rust?

## Why Learn Languages?

We've all dipped our toes in all of the different languages, it's our nature to try things out. We learn a bit about different concepts and practices. It's largely intangible, but it finds us sometimes when we are trying to reason out a problem, an *ah-ha!* moment. We'll take these concepts and apply them over, finding new ways to solve our problems. Exploring languages isn't just *fun* it's *useful*.

Languages aren't created without a reason, and those worth learning will have a few 'defining features' which are interesting to you. What exactly these features are depends on you and what you like to do.

There are many languages, but most can be broken down into a few broad definitions. Let's take a brief overview.

### Systems

Some of us love C (or C++) and it feels natural to us, others hate it, but we all recognize there are warts. They are the mainstay systems languages. We use libraries to cover up warts, and we deal with bugs in tooling. *Have you seen tools like [PVS-Studio](http://www.viva64.com/en/b/)? They're incredible!* Some of these tools are able to go through great depths of analysis and inform development teams of even very complex issues. As a community, we've made great headways into building better digital infrastructure. Because that's what we do as systems programmers. We build *infrastructure*, `nginx`, `openssh`, `linux`, `libc`, `linux`, `openbsd`, etc. much of the core of computing today is in these languages, and we must necessarily be slow to change. Infrastructure takes time, we have a great responsibility.

> [**Paper:** Bugs as Deviant Behavior](http://web.stanford.edu/~engler/deviant-sosp-01.pdf)

> [**Article:** PVS-Studio Blog - Criticizing the Rust Language, and Why C/C++ Will Never Die](http://www.viva64.com/en/b/0324/)

### Functional

Then there are the immensely powerful and composable functional languages like Haskell. Some of them even work on top of familiar things like the Java Virtual Machine. Many of these feature incredible type systems and very robust safety against common bugs. After nights of fiddling with our first *moderately serious* functional adventure, we proudly declare that our program compiles, and that must mean it works. It does. For many of us, the idea of a correct, safe, understandable program is a constant goal. These systems can drive powerful mechanisms that solve **hard** problems. We build the next generation of safe, dependable, powerful systems, and we influence everything around us.

> [**Article:** Facebook - Fighting spam with Haskell](https://code.facebook.com/posts/745068642270222/fighting-spam-with-haskell/)

> [**Repository:** Stripe - Brushfire](https://github.com/stripe/brushfire)

### Scripting

The scripting languages, like Python, Perl, Ruby, and Bash are interwoven into our systems. Even if we do not code in them we at least know the syntax and some idioms. For many of us, it's practically a necessity, for bug reports, build scripts, dependencies, or integrations. For others, it's our mainstay, python powers package managers like `pacman`, web apps, things like `numpy` and `scipy` are invaluable to some disciplines. Ruby underlays gigantic websites like Github, as well as thousands of sites through Ruby on Rails. When we work in these we are the hobbyists, integrators, prototypers, and creatives. We value clean, concise code with high expressiveness and a good library ecosystem. Things like list comprehensions, templating, and interactive debugging are beautiful to us.

> [**Article:** Skylight - Bending the Curve: Writing Safe & Fast Native Gems With Rust](http://blog.skylight.io/bending-the-curve-writing-safe-fast-native-gems-with-rust/)

> [**Article:** Armin Ronacher (Pocoo) - A Fresh Look at Rust](http://lucumr.pocoo.org/2014/10/1/a-fresh-look-at-rust/)

### Web

The vast majority of us have at least a grudging understanding of the language of the web, Javascript. Some of us avoid it like the plague, others transpiler to us using things like Coffeescript and TypeScript, and some of us try to improve the root of the issue. Others even use it on their servers with Node. Web browsers have incredibly powerful tools in the hands of those who understand how to use them. Our creations are temporal (starting and stopping with a tab or deploy) and rarely stateful, talking to external sources for our data. Being able to manipulate APIs, the DOM, and work with callbacks teaches you about asyncronous programming, networking, interchange formats, and the representation of ideas. We are the innovators and communicators, we value agility, ecosystem, and lack of frustration.

> [**Article:** Brendan Eich: From ASM.JS to WebAssembly](https://brendaneich.com/2015/06/from-asm-js-to-webassembly/)
