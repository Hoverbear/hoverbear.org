---
layout: post
title: "A Ghost OpenRC Script"

tags:
  - Tutorials
---

Whipped up an OpenRC script for [Ghost](https://ghost.org/). Feel free to use it for yourself.

Things to be aware of:

* The script was designed for [Funtoo](http://www.funtoo.org/Welcome).
* The script expects Ghost to be in `$GHOST_ROOT`.
* The script runs Ghost as `$GHOST_USER:$GHOST_GROUP`.
* The script exports the `$NODE_ENV` to `production`.

```bash
#!/sbin/runscript

# PATH should only include /usr/* if it runs after the mountnfs.sh script
PATH=/sbin:/usr/sbin:/bin:/usr/bin
DESC="Ghost"
NAME=ghost
GHOST_ROOT=/var/ghost
GHOST_GROUP=ghost
GHOST_USER=ghost
DAEMON=/usr/bin/node
DAEMON_ARGS="$GHOST_ROOT/index.js"
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME
export NODE_ENV=production
source /lib64/rc/sh/functions.sh

depend() {
  use logger dns
  need net
}

start() {
  ebegin "Starting ${DESC}"
  start-stop-daemon --start --quiet   \
    --user $GHOST_USER:$GHOST_GROUP   \
    --chdir $GHOST_ROOT --background  \
    --make-pidfile --pidfile $PIDFILE \
    --exec $DAEMON -- $DAEMON_ARGS
  eend $?
}

stop() {
  ebegin "Stopping ${DESC}"
  start-stop-daemon --stop --quiet     \
  	--retry=TERM/30/KILL/5 --pidfile \
    $PIDFILE --exec $DAEMON
  eend $?
}
```
