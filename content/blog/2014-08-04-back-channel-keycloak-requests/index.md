+++
title = "Back Channel Keycloak Requests"
aliases = ["2014/08/04/back-channel-keycloak-requests/"]
template = "blog/single.html"
[taxonomies]
tags = [
  "UVic",
  "Tutorials",
]
+++


While using [Keycloak](http://keycloak.jboss.org/) you may need to make authenticated requests between various services. How can this be accomplished with [Immutant](http://immutant.org/)?

> You may want to check [this](/2014/07/25/integrating-immutant-and-keycloak/) link to learn how to use Immutant with Keycloak.

<!-- more -->

## Concept

In this deployment, there are three components to the deployment, a **Consumer**, a **Provider**, and **Keycloak**. The **Consumer** makes a request of the **Provider** using authentication through **Keycloak**.

**Workflow:**

* **User** visits **Consumer**, gets redirected to **Keycloak**.
* **User** authenticates with **Keycloak**, gets redirected back to **Consumer**.
* **Consumer** uses the **User**'s "Bearer" token in a back channel request to the **Provider**.
* **Provider** verifies the **User**'s "Bearer" token with **Keycloak**.
* **Provider** returns data to **Consumer** which returns it to the **User** after performing arbitrary computations.

## Preparation

Deploy out a Keycloak container, and scaffold a pair of Immutant applications. In Keycloak, create a **Consumer** application, and a **Provider** application with **User** roles for both. In the **Consumer**'s `web.xml`, restrict the `/backchannel` route to only authenticated **User** roles. Do the same thing with `/locked` on the **Provider**.

## Setting Up Keycloak

As of the 1.0.0-3 BETA version Keycloak currently requires you to declare the scopes necessary for your application. **In 1.0.0-4 BETA, applications will have full role access by default, so this section is not applicable.**

Currently, Keycloak does not grant applications any "Scopes" with other applications, scopes allow you to restrict which role mappings are studded into an access token. In Keycloak, go to the prepared appliactions and under the "Scopes" tab, select the *other* application and give it the **User** scope.

## Making a Request

The **User** will browse to the **Consumer** and authenticate with **Keycloak**, then return to the `/backchannel` route. Since at this point they will be authenticated, you can get their session and utilize the Token it provides.

The `get-session` function produces a session which can be utilized.  

```clojure
(defn get-session
  "Gets the session, get the object with `.getToken` or the access token itself with `.getTokenString`"
  [request]
  (let [{servlet-request :servlet-request} request
        session (.getAttribute servlet-request "org.keycloak.KeycloakSecurityContext")]
    session))
```

`back-channel-handler`, which is bound to the `/backchannel` route, responds to the request with information regarding the users resource access, as well as the data sent from the provider.

```clojure
(defn back-channel-handler
  "A back channel request handler"
  [request]
  (str "The back call resulted in:<br>"
    (.getResourceAccess (.getToken (get-session request)))
    "<br>"
    (try
      (client/get "http://provider:8080/locked"
        {:headers {
          "Authorization" (str "Bearer " (.getTokenString (get-session request)))
        }})
      (catch Exception e
        (str "Exception occured... <pre>" e "</pre>")))))

(defroutes app
  "The router."
  (GET "/backchannel" [:as request] (back-channel-handler request)))
```

## Handling a Request

On the **Provider**, lock down the `/locked` route in the `web.xml` file. Then, Keycloak provides all of the necessary facilities to handle and verify the request. By the time the request reaches the **Provider**, it's already verified that the user has access.
