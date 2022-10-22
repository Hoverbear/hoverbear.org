+++
title = "Deploying Immutant to Wildfly"
aliases = ["2014/07/22/deploying-immutant-to-wildfly/"]
template = "blog/single.html"
[taxonomies]
tags = [
  "UVic",
  "Tutorials",
]
+++

Currently, the [tutorial on deploying to Wildfly with Immutant 2](http://immutant.org/tutorials/wildfly/index.html) is not written. Furthermore,the JBoss documentation isn't particularly tailored towards Clojure applications.

So, let's take a look at how to do this using the convenient [dockerfiles provided by the JBoss project](https://registry.hub.docker.com/u/jboss/). We'll use Docker to simplify deployment and setup of Wildfly, but instructions for a non-docker application should be similar.

### Create a basic Immutant application.
Starting from a `lein new app learning` command, set up your project like so:

<!-- more -->

**project.clj**:

```clojure
(defproject learning "0.1.0-SNAPSHOT"
  :description "FIXME: write description"
  :url "http://example.com/FIXME"
  :license {:name "MPL"
            :url "http://choosealicense.com/licenses/mpl-2.0/"}
  :dependencies [[org.clojure/clojure "1.6.0"]
                 [org.immutant/immutant "2.x.incremental.186"]
                 [compojure "1.1.8"]]
  :repositories [["Immutant incremental builds"
                  "http://downloads.immutant.org/incremental/"]]
  :plugins [[lein-immutant "2.0.0-SNAPSHOT"]]
  :ring {:handler learning.core/app}
  :main ^:skip-aot learning.core
  :target-path "target/%s"
  :profiles {:uberjar {:aot :all}})
```

Note how `lein-immutant` is in the `:plugins` field. This will give us access to the `lein immutant <command>` commands.

**src/learning/core.clj**:

```clojure
(ns learning.core
  (:use compojure.core)
  (:require [compojure.route    :as route]
            [immutant.web       :as immutant])
  (:gen-class))

(defn handler
  "Comment"
  []
  "<h1>Hello World</h1>")

(defroutes app
  "The router."
  (GET "/learning/test" [] (handler))
  (route/not-found
       "<h1>Page not found</h1>"))

(defn -main
  "Start the server"
  [& args]
  (immutant/run app))
```

After speaking to the fine folks on the #immutant IRC channel on Freenode, we determined that Immutant seemed to have some issues with routing while running on JBoss. The route `/learning/test` *should* be just `/test` as far as I am able to tell, the problem will become apparent later.

**Dockerfile**:

```
FROM jboss/wildfly
RUN /opt/wildfly/bin/add-user.sh hoverbear hunter2 --silent
ADD target/base+system+user+dev/learning.war /opt/wildfly/standalone/deployments/
```

### Build the Immutant Application

Wildfly seems to expect `.war` files for deployment. Thankfully Immutant provides this via the plugin declared in the `project.clj`.

```bash
lein immutant war
```

The output should be similar to:

```bash
➜ lein immutant war
Compiling learning.core
Created /home/hoverbear/learning/target/uberjar/learning-0.1.0-SNAPSHOT.jar
Created /home/hoverbear/learning/target/uberjar/learning-0.1.0-SNAPSHOT-standalone.jar
Creating /home/hoverbear/learning/target/base+system+user+dev/learning.war
```

Notice how the resulting `.war` file is the same which is ADDed by the `Dockerfile`.

### Building the Docker Image

Next, build the Docker image, make sure you're in the project directory.

```bash
docker build -t wildfly-learning .
```

If you haven't pulled the `jboss/wildfly` base image before, this first command might take awhile. Future builds will be very fast as it won't need to pull the base image.

### Running the Container

```bash
docker run -p 8080:8080 -p 9990:9990 wildfly-learning
```

There should be a considerable log of output.

### Testing

From there, you should be able to visit `http://localhost:8080/learning/test` and see "Hello World" in bold text. Visiting any other `/learning/*` url should yield a bold "Page not found" with a smaller 404 error underneath. Visiting a URL like `/learn` will give a different 404 page.

### Visiting the Wildfly console

You should be able to visit `http://localhost:9990/console/App.html` and view the Wildfly admin interface, you might need to log in with details from the Dockerfile.

Browsing to the "Runtime > Manage Deployments" page will allow you to play with some settings.

### Notes
This is, obviously, not a production deployment.
