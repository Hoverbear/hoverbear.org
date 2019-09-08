+++
title = "Integrating Immutant and Keycloak"
aliases = ["2014/07/25/integrating-immutant-and-keycloak/"]
layout = "blog/single.html"
[taxonomies]
tags = [
  "UVic",
  "Tutorials"
]
+++


In my past two posts, we took a [surface level look at Immutant](/2014/07/14/starting-with-immutant/) then took a look at [deploying immutant applications to the Wildfly application server.](/2014/07/22/deploying-immutant-to-wildfly/) This time, we'll take a look at how to integrate Keycloak with an Immutant app, again using Docker heavily.

> If you haven't read the previous few articles, it might be useful to give them a quick glance over.

<!-- more -->

## Keycloak

### Erecting Keycloak

[Keycloak](http://keycloak.jboss.org/) is an integrated Single-Sign-On and Identity Management platform from the fine folks of JBoss. A Docker image of Keycloak is available [here](https://www.jboss.org/docker/), just like Immutant, Wildfly, and a few others.

To pull the Keycloak image:

```bash
docker pull jboss/keycloak
```

Then, to erect the container ([Source](https://github.com/jboss/dockerfiles/blob/master/keycloak/server/README.md)):

```bash
docker run -it --name keycloak -p 8080:8080 -p 9090:9090 jboss/keycloak
```

> Use the  `-d` flag to daemonize the service so it doesn't die with the tty. You can check the logs later with `docker logs -f keycloak`

Finally, you should be able to browse to [http://localhost:8080/](http://localhost:8080/) and see the friendly Wildfly logo and welcome screen. Visiting [http://localhost:8080/auth/](http://localhost:8080/auth/) should yield a Keycloak welcome screen.

### Getting into Keycloak

Visiting [http://localhost:8080/auth/admin/](http://localhost:8080/auth/admin/) should bring you to a very *blue* login screen. The Keycloak docker image starts with a pre-created `admin` account for you to log in with.

**Username:** admin

**Password:** admin

After logging in, Keycloak should prompt for a password change.

### Creating an Application

Browse to the **Applications** menu and hit the blue **Add Application** button. For this exploration, I'm creating a `learning` application.

**Name:** learning

**Enabled:** ON

**Access Type:** confidential

**Redirect URI:** http://localhost:8081/\*

After hitting save, you'll have the opportunity to add more information. For this exploration, we don't need to add any more information here.

Visiting the **Roles** tab at the top, hit **Add Role** and create a pair of roles:

* `user`
* `admin`

There are several other tabs which contain many more interesting configuration options, but we'll leave these alone for now.

### Creating Some Users

In our exploration, we'll utilize both of the scopes above to see how to allow different roles to access different parts of the site.

Browse over to the **Users** menu. Beside the search box, hit **View all Users**. You should see `admin` already created. Create a `user` user, the rest of the information you can use anything, or nothing.

Going back to the user listing. Select the `admin` user and go to the **Role Mappings** tab. At the bottom in "Application Roles" select `learning` from the dropdown. Add the `admin` role for the admin user. Then, repeat the steps for the `user` user, but only assign them the `user` role, not `admin`.

*What does this all mean?* The `admin` user should be able to access every page the `admin` role can. The `user` user should *not* be able to access the `admin` role's pages.

## Immutant

### Setting Up the Immutant Application

Start up a new lein project with:

```bash
lein new app learning
```

Your `learning/project.clj` needs to be modified to look similar to this:

```clojure
(defproject learning "0.1.0-SNAPSHOT"
  :description "FIXME: write description"
  :url "http://example.com/FIXME"
  :license {:name "MPL"
            :url "http://choosealicense.com/licenses/mpl-2.0/"}
  :dependencies [[org.clojure/clojure "1.6.0"]
                 [org.immutant/immutant "2.x.incremental.191"]
                 [compojure "1.1.8"]]
  :repositories [["Immutant incremental builds"
                  "http://downloads.immutant.org/incremental/"]]
  :plugins [[lein-immutant "2.0.0-SNAPSHOT"]]
  :main ^:skip-aot learning.core
  :target-path "target/%s"
  :profiles {:uberjar {:aot :all}}
  ; Plugin configuration.
  :ring {:handler learning.core/app}
  :immutant {
     :war {
        :dev? false
        :resource-paths ["resources"]
        :nrepl {
          :port 8888
          :start? true}}})
```

Now change your `learning/src/learning/core.clj` file to contain the following:

```clojure
(ns learning.core
  (:use compojure.core)
  (:require [compojure.route       :as route]
            [immutant.web          :as web]
            [immutant.web.servlet  :as servlet])
  (:gen-class))


(defn get-token
  "Gets the session for the user"
  [request]
  (let [{servlet-request :servlet-request} request
        security-context (.getAttribute servlet-request "org.keycloak.KeycloakSecurityContext")
        id-token (.getIdToken security-context)]
    id-token))

(defn show-profile
  "Shows the profile of the user"
  [request]
  (try
    (let [token (get-token request)]
      ; The token is a Java Object, don't expect more then a reference.
      (str "<p>Token is: <pre>" token "</pre></p>"
           ; This should show the users name.
           ; Reference: https://docs.jboss.org/keycloak/docs/1.0-beta-3/javadocs/org/keycloak/representations/IDToken.html
           "<p>User is: <pre>" (.getPreferredUsername token) "</pre></p>"))
    (catch Exception e
      ; There is no token.
      (str "<p>No user found.</p><pre>" e "</pre>"))))

(defn test-handler
  "A very versatile test route handler"
  ; Handled different arities.
  ([request base]
   (str "<h1>Base: " base "</h1>"
        "<p>" (show-profile request) "</p>"))
  ([request base sub]
   (str "<h1>Base: " base " Sub: " sub "</h1>"
        "<p>" (show-profile request) "</p>"))
  ([request base sub subsub]
   (str "<h1>Base: " base " Sub: " sub " Subsub: " subsub "</h1>"
        "<p>" (show-profile request) "</p>")))

(defroutes app
  "The router."
  ; Logout
  ; Doesn't currently work: https://issues.jboss.org/browse/KEYCLOAK-478
  (GET "/logout" [:as request]
    (let [{servlet-request :servlet-request} request]
      (.logout servlet-request)
      (str "Logged out")))
  ; Rest of the routes.
  (GET "/" [:as request]
       (test-handler request "/"))
  (GET "/:base" [base :as request]
       (test-handler request base))
  (GET "/:base/:sub" [base sub :as request]
       (test-handler request base sub))
  (GET "/:base/:sub/:subsub" [base sub subsub :as request]
       (test-handler request base sub subsub))
  (route/not-found "<h1>Page not found</h1>"))

(defn -main
  "Start the server"
  [& args]
  ; Start the server.
  (web/run (servlet/create-servlet app) :port 8081))
```

The `get-token` function returns an object that you can run things like `(.getPreferredUsername token)`. [This](https://docs.jboss.org/keycloak/docs/1.0-beta-3/javadocs/org/keycloak/representations/IDToken.html) documents the different methods you can use.

### Planning the Routes

The routes are specifically very, very general so that we can test various routes. In our exploration we'll be paying attention to the following routes:

* `/logout` - Logs out the user. (Note: [This is currently broken in Keycloak-1.0.0-beta-3](https://issues.jboss.org/browse/KEYCLOAK-478))
* `/test` and `/test/foo` - General routes available to all visitors.
* `/locked` and `/locked/foo` - Routes available to all `user` and `admin` roles.
* `/admin` and `/admin/foo` - Routes available to only administrators.

The routes in our code above covers much, much more then those, but you can play with those on your own.

### Integrating Keycloak

[Keycloak's User Guide](http://keycloak.jboss.org/docs.html) specifies how to secure the application via the `web.xml`. If you're familiar with JBoss (I'm not) this is apparently a fairly standard way of securing the application.

However, Immutant does not currently provide an easy way to modify the `web.xml` in the war files it builds. Thankfully, since a war is a jar, and a jar is a zip, we can just add it in after.

First, lets make a folder for this type of data in `/learning/resources`.

```bash
mkdir resources/WEB-INF
```

Then, create a `learning/resources/WEB-INF/web.xml` with the following XML:

```xml
<web-app xmlns="http://java.sun.com/xml/ns/javaee" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://java.sun.com/xml/ns/javaee http://java.sun.com/xml/ns/javaee/web-app_3_0.xsd" version="3.0">
	<distributable/>
	<listener>
		<listener-class>org.projectodd.wunderboss.wildfly.ServletListener</listener-class>
	</listener>

	<!-- Anyone -->
	<security-constraint>
		<web-resource-collection>
			<web-resource-name>test</web-resource-name>
			<url-pattern>/test</url-pattern>
			<url-pattern>/test/*</url-pattern>
		</web-resource-collection>
	</security-constraint>

	<!-- Users and Admins -->
	<security-constraint>
		<auth-constraint>
			<role-name>user</role-name>
			<role-name>admin</role-name>
		</auth-constraint>
		<web-resource-collection>
			<web-resource-name>locked</web-resource-name>
			<url-pattern>/locked</url-pattern>
			<!-- Wildcard. Covers /locked/foo, /locked/foo/bar, etc -->
			<url-pattern>/locked/*</url-pattern>
		</web-resource-collection>
	</security-constraint>

	<!-- Admins -->
	<security-constraint>
		<auth-constraint>
			<role-name>admin</role-name>
		</auth-constraint>
		<web-resource-collection>
			<web-resource-name>admin</web-resource-name>
			<url-pattern>/admin</url-pattern>
			<!-- Wildcard. Covers /admin/foo, /admin/foo/bar, etc -->
			<url-pattern>/admin/*</url-pattern>
		</web-resource-collection>
	</security-constraint>

	<!-- Logout Route -->
	<security-constraint>
		<auth-constraint>
			<role-name>admin</role-name>
			<role-name>user</role-name>
		</auth-constraint>
		<web-resource-collection>
			<web-resource-name>logout</web-resource-name>
			<url-pattern>/logout</url-pattern>
		</web-resource-collection>
	</security-constraint>

	<!-- Keycloak conf -->
	<login-config>
		<auth-method>KEYCLOAK</auth-method>
		<realm-name>master</realm-name>
	</login-config>

</web-app>
```

Now, navigate back to your [Keycloak container](https://localhost:8080/auth), log in, and go to the **Applications** menu, hit **learning**, and go to the **Installation** tab. Select the `keycloak.json` from the dropdown. Finally, **Download** the output and save it as `learning/WEB-INF/keycloak.json`.

### Building the container

Since we'll be using a Docker container for the application, create a `learning/Dockerfile` with the following:

```
FROM jboss/keycloak-adapter-wildfly
RUN /opt/wildfly/bin/add-user.sh admin hunter2 --silent
ADD target/base+system+user+dev/learning.war /opt/wildfly/standalone/deployments/ROOT.war
```

Then a `learning/Makefile` to (optionally) make things a bit smoother:

```make
all:
	docker rm -f immut-test || true
	docker rmi immut-learning || true
	lein immutant war
	docker build -t immut-learning .

run:
	docker run --name immut-test --rm -t -i -p 127.0.0.1:8081:8080 -p 127.0.0.1:9991:9990 --link keycloak:auth immut-learning
```

**Just one more thing:** Due to the linking between containers, you may need to add a line to your `/etc/hosts` so that the application will appropriately talk to the Keycloak server. The line should look like this:

```
127.0.0.1 auth
```

Then, edit your `keycloak.json` and set the `auth-server-url`:

```json
"auth-server-url": "http://auth:8080/auth",
```

## Running

You should now be able to build **and start** the application with:

```bash
make && make run
```

After waiting for boot, browsing to [http://localhost:8081/test](http://localhost:8081/test) should yield you a page that says, roughly:

```
Base = "test"

No user found.

java.lang.NullPointerException
```

## Exploring

### User routes

Now, try visiting [http://localhost:8081/locked](http://localhost:8081/locked). You should get redirected to the familiar Keycloak login screen. Log in with the `user` account. You should see something roughly like:

```
Base = "locked Sub: test"

Token is:

org.keycloak.representations.IDToken@7f55bb4f

User is:

user

```

*Fantastic*. Now, try navigating to the admin route at [http://localhost:8081/admin](http://localhost:8081/admin). You should see the helpful `Forbidden` error. This is exactly what we want!

### Admin routes

In order to change accounts, you, unfortunately, can't browse to [http://localhost:8081/logout](http://localhost:8081/logout). This seems to be a bug to be squashed in the next version of Keycloak ([Bug](https://issues.jboss.org/browse/KEYCLOAK-478)), but I'll leave it here for posterity. For now, navigate to [http://localhost:8080/auth](http://localhost:8080/auth), log in as `admin`, navigate to the **Sessions and Tokens** and click the blue **Logout All** button.

Browse back to [http://localhost:8081/admin](http://localhost:8081/admin) and log in as `admin`. You should see:

```
Base = "admin"

Token is:

org.keycloak.representations.IDToken@4a8ca873

User is:

admin
```

You should also be able to hit all other routes as the admin. Be sure to explore Keycloak, as it has many features regarding roles, permissions, and other things not covered here.


**Special thanks to all the folks on #immutant, especially bbrowning, tcrawley, and jcrossley3 for their help!**
