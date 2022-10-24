+++
title = "Raft: Tooling & Infra Update"
aliases = ["2015/07/23/raft-tooling/"]
template = "blog/single.html"
[taxonomies]
tags = [
  "Rust",
  "Raft",
  "Tooling",
]
+++

In preparation for the forthcoming 0.0.1 release of Raft we've taken several forward steps to improve our (already pretty darn cool!) tooling and infrastructure. If you attempt to set up any of these on your own and have issues let me know! I'd be more than happy to help. You can find our [`.travis.yml` here](https://github.com/Hoverbear/raft/blob/master/.travis.yml).

<!-- more -->

## `sudo`-less

Travis CI released [their container infrastructure](http://blog.travis-ci.com/2014-12-17-faster-builds-with-container-based-infrastructure/) last year, and we finally started using it! We'd tried before however we struggled with packages, as Cap'n Proto has rather demanding dependencies for a C++11 compiler.

In case anyone is looking, here is the secret sauce on how to build Cap'n Proto on Travis CI without root:

```yaml
addons:
  apt:
    sources:
      - ubuntu-toolchain-r-test
    packages:
        # Needed for building Cap'n Proto.
      - gcc-4.8
      - g++-4.8

# We need to install Cap'n Proto.
install:
    - git clone https://github.com/kentonv/capnproto.git
    - cd capnproto/c++
    - ./setup-autotools.sh
    - autoreconf -i
    - ./configure --disable-shared
    - make -j5
    - export PATH="$PATH:$(pwd)"
    - export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$(pwd)"
    -  cd ../..
```

Now that we've flagged `sudo: false` in our `.travis.yml` our Travis *wait time* for a build have significantly decreased. Some of our test builds take under 1:45 minutes!

## Moved to [`travis-cargo`](https://github.com/huonw/travis-cargo)

Huon created the fantastic `travis-cargo` crate and we recently moved over to it! This helped clean up the `.travis.yml` a bit and opened the door for us to utilize future improvements. This took our `.travis.yml` script section from this:

```yaml
# Generate Docs
after_success = "|"
  [ $TRAVIS_BRANCH = master ] &&
  [ $TRAVIS_PULL_REQUEST = false ] &&
  cargo doc &&
  echo '<meta http-equiv=refresh content=0;url=raft/index.html>' > target/doc/index.html &&
  sudo pip install ghp-import &&
  ghp-import -n target/doc &&
  git push -fq https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git gh-pages
```

To this:

```yaml
# Load `travis-cargo`
before_script:
    - pip install 'travis-cargo' --user
    - export PATH=$HOME/.local/bin:$PATH

script:
    - travis-cargo build
    - travis-cargo test
    - travis-cargo bench
    - travis-cargo doc

# Generate Docs and coverage
after_success:
    - travis-cargo doc-upload
    - travis-cargo coveralls --no-sudo
```

With `travis-cargo` our builds are more thorough, clear, and featured. It handles uploading our documentation, code coverage, benchmarking, and the whole kaboodle.

## Code Coverage

You may have noticed the `travis-cargo coveralls --no-sudo` above and wondered what that was. [`http://coveralls.io/`](http://coveralls.io/) offers free code coverage analysis to open source projects. You can see what ours looks like [here](https://coveralls.io/github/Hoverbear/raft).

We're currently sitting at:

[![Coverage Status](https://img.shields.io/coveralls/Hoverbear/raft/master.svg)](https://coveralls.io/github/Hoverbear/raft)

Code coverage. Wow! That's not bad! We hope to improve this as we go.

## [@homu](http://homu.io/)

We also adopted the friendly robot homu to be our repository gatekeeper. If you've been around Rust or Servo you probably know bors, homu is a rewrite of bors.

homu acts sort of like a pre-commit hook, testing pull requests *just before* they're merged. Much of the work to get `sudo`-less builds was in preparation for homu since we wanted it to be *fast!*

With homu guarding the `master` branch we can be sure that Raft will stay "green" on tests unless I manage to accidently push to master, or one of our dependencies breaks.
