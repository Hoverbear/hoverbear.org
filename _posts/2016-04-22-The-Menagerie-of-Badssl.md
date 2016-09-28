---
layout: post
title: "The Menagerie of Badssl"

image: /assets/images/2016/04/menagerie.jpg
image-credit: "Samuel Scrimshaw"

tags:
  - UVic
---

Late last year I was given an opporunity to participate in the Mozilla Winter of Security 2016! I'm happy to report it was, and still is, super cool. Plans diverted significantly at the very start of the project as it was discovered that the "menagerie" of certificates we wanted to build already existed.

What joy! In order to avoid any "not-invented-here" syndrome problems we pivoted, like  a failing startup, and I moved to become a contributor to [BadSSL](http://badssl.com/). One of my mentors, [April King](https://github.com/marumari), happened to already be a contributor to BadSSL and helped me get acquainted with the repository and the maintainer, [Lucas Garron](https://github.com/lgarron/).

I was glad to discover that BadSSL is a [Jekyll](http://jekyllrb.com/) site. I've used Jekyll a number of times for different tasks and really enjoy working with the program. BadSSL is deployed on the [Google Cloud Platform](https://cloud.google.com/) and is primarily powered via extensive nginx configurations.

## Superfish and Dell Fumble ##

In a couple spectacular fumbles by Dell and Lenovo we got a couple really interesting new specimens. [Lenovo's bundled adware 'Superfish' CA](http://blog.erratasec.com/2015/02/extracting-superfish-certificate.html) and [Dell's Curious Customer Service CA](https://blog.hboeck.de/archives/876-Superfish-2.0-Dangerous-Certificate-on-Dell-Laptops-breaks-encrypted-HTTPS-Connections.html) were discovered and compromised. We subsequently added [https://superfish.badssl.com/](https://superfish.badssl.com/), [https://edellroot.badssl.com/](https://edellroot.badssl.com/), and [https://dsdtestprovider.badssl.com/](https://dsdtestprovider.badssl.com/) so that potentially affected users could easily test their systems.

## The Spider's Web ##

One of the problems we identified with the current version of BadSSL was the tangle of files one needs to create or manipulate to generate a new subdomain. As an example, adding the above mentioned 3 subdomains required changing over 18 files. After doing some research I discovered that we could harness the power of Jekyll's `_data` files to our advantage. I have a [Pull Request](https://github.com/lgarron/badssl.com/pull/156) I've been trying to land that will greatly simplify this process and permit further automation.

I really enjoy working with these types of templating and data transformation problems. I've been exploring using [Jekyll Generators](https://jekyllrb.com/docs/plugins/#generators) automate the creation of some remaining crud files however I haven't made any solid progress on that yet.

## A Whale of a Time ##

Those gosh darn whale containers are really hard to set up sometimes. BadSSL had a `Dockerfile` however it wasn't harnessing all of the features it could have. For example Jekyll was called outside of the container, and required the user to have installed it already. April and I spent many hours on IRC coaxing around various steps of the build system to find a happy medium between speed and heft. I think moving forward using a container might be the right choice for production as well.

I'd like to set up a shared-volume based command for filesystem watching, however this will likely involve figuring out how to hook onto post-builds in Jekyll to fire Nginx restarts. Then we could use something like `jekyll serve` inside the container while updating the development copy of the website from outside the container.

## Weaving a Tale ##

Without an explanation of what's being tested it's hard to argue that having tests are worthwhile! BadSSL (until the `data` branch merges) has no comprehensive descriptions about what different certificates represent contextually. The `data` branch, and soon production, features a full set of descriptions embedded into each page as well as on the index.

One thing I learned all too well while compiling this information is that **security is very complicated**. There are so many varieties of cipher suites supporting (or not) many different browsers, operating systems, esoteric configurations, and eras of computing. It makes me worry when I see crypto libraries that advertise configurability these days. I'd much rather see simple and foolproof.

## Smooth Like Butter ##

Descriptions for each specimen of our little menagerie was great, but it made the front page mind-blowingly wordy. So what's a bear to do but resort to tooltips? After looking at various options it was kind of conclusive that most tooltip libraries wouldn't fit our desired use case. We wanted tooltips that wouldn't be invasive, that could include HTML like links, and worked in situations where the client had Javascript disabled.

So instead I wrote up some CSS animations to handle the task. You can see a demo below:

<style>
    #demo {
        padding-bottom: 35pt;
        width: 50%;
        text-align: center;
    }
    #demo > .container {
        margin-top: 10px;
        color: white;
    }
    #demo > .container > a {
        text-decoration: none;
        color: white;
        font-size: 18pt;
        display: block;
        width: 100%;
        box-shadow: 0 3px 6px rgba(0,0,0,0.16), 0 3px 6px rgba(0,0,0,0.23);
        transition: all 150ms;
        font-weight: bold;
        word-wrap: break-word;
        background-color: black;
    }
    #demo > .container > .description {
        background-color: black;
        position: relative;
        z-index: 10;
        text-decoration: none;
        height: 0;
        overflow: hidden;
        width: 100%;
        transition: all 1.5s;
        transition-delay: 300ms;
        word-wrap: break-word;
        top: -10px;
        box-shadow: 0 8px 6px rgba(0,0,0,0.16), 0 8px 6px rgba(0,0,0,0.23);
    }
    #demo > .container:hover > .description {
        height: 34pt;
        margin-bottom: -34pt;
    }
</style>

<div id="demo">
    <div class="container">
        <a>Hover your mouse over me!</a>
        <div class="description">
            I'm a test description! Typically this is a sentence or two, so it tends to need two lines.
        </div>
    </div>
    <div class="container">
        <a>Hover your mouse over me!</a>
        <div class="description">
            I'm a test description! Typically this is a sentence or two, so it tends to need two lines.
        </div>
    </div>
    <div class="container">
        <a>Hover your mouse over me!</a>
        <div class="description">
            I'm a test description! Typically this is a sentence or two, so it tends to need two lines.
        </div>
    </div>
</div>

## A Big Congratulations! ##

As you may have noticed, some of these tasks are yet to be complete or merged, and that's because April had a fantastical life event happen! Her and her partner welcome a new life recently. I'm very happy for both of them and encourage her to take her time to adjust to these new changes. We can continue our work together when she is ready.
