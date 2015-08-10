---
layout: post
title:  "Starting with Immutant"
tags:
 - Clojure
 - Simbioses
 - Tutorials
---

Immutant is suite of **Clojure** libraries that is part of the JBossAS/Wildfly ecosystem. Great, fantastic! Clojure is a lisp that runs on the JVM, the CLR, and compiles to Javascript. Lets get started!

Some links we'll need:

* [Immutant](http://immutant.org/) - The framework.
* [Clojure](http://clojure.org/) - The language.
* [Leiningen](http://leiningen.org/) - The package manager.

### Getting Leiningen

Assuming `~/bin/` is a folder in your `$PATH`

```bash
DEST=~/bin/lein
curl https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein > $DEST
chmod +x $DEST
```

### Getting Clojure

You get Clojure (oddly) through `lein`. Just run it, and it'll download everything it needs.

```bash
lein
```

That was easy!

### Setting up an Immutant Project

*This is a lightly expanded version of [this page](http://immutant.org/tutorials/installation/index.html).*

Use `lein` to initialize a new project.

```bash
lein new app learning
cd learning
```

The folder `learning/` should have a file `project.clj` which you should edit to look like this:

```clojure
(defproject learning "0.1.0-SNAPSHOT"
  :description "FIXME: write description"
  :url "http://example.com/FIXME"
  :license {:name "MPL"
            :url "http://choosealicense.com/licenses/mpl-2.0/"}
  :dependencies [[org.clojure/clojure "1.6.0"]
                 [org.immutant/immutant "2.x.incremental.186"]]
  :repositories [["Immutant incremental builds"
                  "http://downloads.immutant.org/incremental/"]]
  :main ^:skip-aot learning.core
  :target-path "target/%s"
  :profiles {:uberjar {:aot :all}})
```

Note how the dependencies and repositories now contain references to immutant. You should change `186` to the latest incremental build at [this page](http://immutant.org/builds/2x/).

The `project.clj` file is similar to a `package.json` in Node.js or `Cargo.toml` in Rust.

### Your First Route

*This is a lightly expanded version of [this page](http://immutant.org/tutorials/web/index.html).*

In order to have a route (and thus a real web server) you need to add a `require` for immutant to your `src/learning/core.clj`. Then, define the `app` function like so and use `run` to start it:

```clojure
(ns learning.core
  (:use compojure.core)
  (:require [compojure.route :as route]
             [immutant.web :as immutant])
  (:gen-class))

(defn app [request]
  "A basic route for learning."
  {:status 200
   :body "Hello world!"})

(defn -main
  "Start the server."
  [& args]
  (immutant/run app {:host "localhost" :port 8080 :path "/"}))
```

To start the server with `lein run` in the folder.

Now browse to [http://localhost:8080](http://localhost:8080) and you should see something like:

```html
Hello world!
```


### More Routes

You're probably thinking "Well that's great, an app with one route, how useless." You'd be quite right, unless you're implementing [Yo](http://www.justyo.co/) or something.

If you're reading along the [Immutant web tutorial](http://immutant.org/tutorials/web/index.html) you may have noticed in "Advanced Usage" they use multiple `run` functions to serve multiple routes.

To quote:

> ...actually creates two Undertow web server instances: one serving requests for the hello and howdy handlers on port 8080, and one serving ola responses on port 8081.

Not the most desirable option. Looking back up under "Common Usage":

> First, you'll need a Ring handler. If you generated your app using a template from Compojure, Luminus, Caribou or some other Ring-based library, yours will be associated with the :handler key of your :ring map in your project.clj file.

That sounds certainly more desirable. Let's use [Compojure](https://github.com/weavejester/compojure/).

Change your `project.clj`:

```clojure
:dependencies [[org.clojure/clojure "1.6.0"]
               [org.immutant/immutant "2.x.incremental.186"]
               [compojure "1.1.8"]]
```

And then extend your source file.

```clojure
(ns learning.core
  (:use compojure.core)
  (:require [compojure.route :as route]
             [immutant.web :as immutant])
  (:gen-class))


(defn handler
  "Comment"
  []
  "<h1>Hello World</h1>")

(defroutes app
  "The router."
  (GET "/" [] (handler))
  (route/not-found
       "<h1>Page not found</h1>"))

(defn -main
  "Start the server"
  [& args]
  (immutant/run app {:host "localhost" :port 8080 :path "/"}))
```

Now you should have multiple routes.
