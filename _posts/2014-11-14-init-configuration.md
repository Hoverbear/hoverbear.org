---
layout: post
title: "Init - Configuration"

tags:
 - Init
 - Tutorials
 - CSC499
---


An initialization system's main interface with the user is through it's configuration scripts and service files. Let's take a look at what this looks like for systemd and OpenRC.

With systemd, daemon configuration is handled by `.toml` configuration files. With OpenRC, this task is performed by shell scripts.


# Daemons and services

systemd stores service files in `/etc/systemd/system/` (user-provided) or `/usr/lib/systemd/system/` (package-provided). `.service` files are used to declare configuration.

OpenRC stores scripts in `/etc/init.d/`, the scripts are typically standalone, configuration does not require multiple separate files.

Here is the contents of `/etc/systemd/system/sshd.service` on a Fedora 20 system:

```toml
[Unit]
Description=OpenSSH server daemon
After=syslog.target network.target auditd.service

[Service]
EnvironmentFile=/etc/sysconfig/sshd
ExecStartPre=/usr/sbin/sshd-keygen
ExecStart=/usr/sbin/sshd -D $OPTIONS
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
RestartSec=42s

[Install]
WantedBy=multi-user.target
```

For comparison, this is an excerpt of `/etc/init.d/sshd` on Funtoo Linux, not the entire file:

```bash
depend() {
  use logger dns
  if [ "${rc_need+set}" = "set" ]; then
    : # Do nothing, the user has explicitly set rc_need
  else
    warn_addr=''
    for x in $(awk '/^ListenAddress/{ print $2 }' "$SSHD_CONFIG" 2>/dev/null) ; do
      case "$x" in
        0.0.0.0|0.0.0.0:*) ;;
        ::|\[::\]*) ;;
        *) warn_addr="${warn_addr} $x" ;;
      esac
    done
    unset x
    if [ "${warn_addr:+set}" = "set" ]; then
      need net
      ewarn "You are binding an interface in ListenAddress statement in your sshd_config!"
      ewarn "You must add rc_need=\"net.FOO\" to your /etc/conf.d/sshd"
      ewarn "where FOO is the interface(s) providing the following address(es):"
      ewarn "${warn_addr}"
    fi
    unset warn_addr
  fi
}

start() {
  checkconfig || return 1

  ebegin "Starting ${SVCNAME}"
  start-stop-daemon --start --exec "${SSHD_BINARY}" \
      --pidfile "${SSHD_PIDFILE}" \
      -- ${SSHD_OPTS}
  eend $?
}

stop() {
  if [ "${RC_CMD}" = "restart" ] ; then
    checkconfig || return 1
  fi

  ebegin "Stopping ${SVCNAME}"
  start-stop-daemon --stop --exec "${SSHD_BINARY}" \
      --pidfile "${SSHD_PIDFILE}" --quiet
  eend $?
}
```

An important distinction to note is that while systemd's configuration is **declarative**, OpenRC's configuration is **programmatic**. The decision to use a declarative method was explained in [this](http://0pointer.de/blog/projects/systemd.html) article under the "Keeping the First User PID Small" heading.

> Shell is fast and shell is slow. It is fast to hack, but slow in execution. The classic sysvinit boot logic is modelled around shell scripts.

One of systemd's main goals, at least in regards to services, is to start them **fast**, and for this reason they are willing to sacrifice some flexibility. Due to successful deployments of systemd in Arch Linux and Fedora (among others), this idea has been proven feasible.

For many services, a full blown shell script is not necessary. For example, with OpenRC's `sshd` script the `start` and `stop` jobs really only check the configuration of the service (`checkconfig` is defined elsewhere in the file) and then invoke `start-stop-daemon`. It's possible to simply call a shell script from a systemd service, but this forces the use of multiple files, and results in a loss of the speed gained from not utilizing the shell.

## Dependencies

In systemd dependencies are handled via the declarations `Wants`, `Requires`, and `After` in the `[Unit]` section of the `.service`. For more info visit [Arch Linux's SystemD Dependencies Section](https://wiki.archlinux.org/index.php/systemd#Handling_dependencies). For example:

**/etc/systemd/system/A.service**

```toml
[Unit]
# Optionally depends on `C` and `D`.
Wants=C.service D.service
# Start after `D`, but concurrently with `C`
After=D.service
```

**/etc/systemd/system/B.service**

```toml
[Unit]
# Strictly depend on A and Networking.
Requires=A.service Networking.target
# Start after `A`, but concurrently with `Networking`
After=A.service
```

It's rather fascinating that `Requires` and `Wants` do not imply `After` for their specified services. It does make sense though, many services do not immediately require their attached services.

For OpenRC, dependencies are handled by the `depend` function of the script. For more info visit [The Funtoo OpenRC Page](http://www.funtoo.org/Package:OpenRC).

**/etc/init.d/nginx**

```bash
depend() {
	need net
	use dns logger netmount
}
```

There are five options:

* `need` introduces a hard dependency (like `Require`)
* `use` is a soft dependency which will only invoke if the depended upon service is also on the same runlevel.
* `after` functions like `After` in system, making sure this service starts after the specified one.
* `provide` can be used to allow the service to 'stand in' for another. For example, MariaDB and MySQL could both `provide sql`.
* `keyword` allows for overrides. Check the documentation for more on this.

## Other files

Systemd uses a number of extra file types. Some examples are:

* `.wants`, a folder with symlinks to services that are a needed by a target. For example, `/usr/lib/systemd/system/multi-user.target` has a cooresponding folder `/usr/lib/systemd/system/multi-user.target.wants` with symlinks to service files like `systemd-logind.service`, and `systemd-user-sessions.service` on CentOS 7.
* `.socket`, denotes a [socket activated](http://www.freedesktop.org/software/systemd/man/systemd.socket.html) configuration. It's possible to set up certain services in systemd to not start until their socket is activated on the system.
* `.timer`, denotes a [timer based](http://www.freedesktop.org/software/systemd/man/systemd.timer.html) activation. This fulfills some of the same roles as programs like `vixiecron` and `fcron`.

OpenRC allows for files in `/etc/conf.d` to be sourced for scripts of the same name in `/etc/init.d`. The advantage of this is that most scripts in `/etc/init.d` won't need to be modified (and thus can be updated safely). This is a collary to the [Store config in the environment](http://12factor.net/config) section of the 12factor methodology.

> Encourage the separation of configuration and runtime.

Here we can see the origin of the `${SSHD_OPTS}` from the earlier example of `/etc/init.d/sshd`:

**/etc/conf.d/sshd**:

```bash
# /etc/conf.d/sshd: config file for /etc/init.d/sshd
# Where is your sshd_config file stored?
SSHD_CONFDIR="/etc/ssh"

# Any random options you want to pass to sshd.
# See the sshd(8) manpage for more info.
SSHD_OPTS=""

# Pid file to use (needs to be absolute path).
#SSHD_PIDFILE="/var/run/sshd.pid"


# Path to the sshd binary (needs to be absolute path).
#SSHD_BINARY="/usr/sbin/sshd"
```

# Configuring Init Itself

OpenRC is configured the same way as most traditional Linux/BSD services are configured. The default configuration on Funtoo is well commented and usually self-explanatory, even including gotchas in their notes. There are a few knobs to tweak based on user preferences.

**/etc/rc.conf**:

```bash
# Set to "YES" if you want the rc system to try and start services
# in parallel for a slight speed improvement. When running in parallel we
# prefix the service output with its name as the output will get
# jumbled up.
# WARNING: whilst we have improved parallel, it can still potentially lock
# the boot process. Don't file bugs about this unless you can supply
# patches that fix it without breaking other things!
rc_parallel="YES"

# rc_logger launches a logging daemon to log the entire rc process to
# /var/log/rc.log
# NOTE: Linux systems require the devfs service to be started before
# logging can take place and as such cannot log the sysinit runlevel.
rc_logger="YES"
```

systemd's configuration is similarly accessible in `/etc/systemd/*.conf`, from there it's possible to set things like the default CPU limits for processes and other things.

**/etc/systemd/system.conf**:

```toml
[Manager]
#CPUAffinity=1 2
#DefaultStandardOutput=journal
#DefaultStandardError=inherit
#JoinControllers=cpu,cpuacct net_cls,net_prio
#RuntimeWatchdogSec=0
#ShutdownWatchdogSec=10min
#CapabilityBoundingSet=
#TimerSlackNSec=
#DefaultTimeoutStartSec=90s
#DefaultTimeoutStopSec=90s
#DefaultRestartSec=100ms
#DefaultStartLimitInterval=10s
#DefaultStartLimitBurst=5
#DefaultEnvironment=
#DefaultLimitCPU=
#DefaultLimitFSIZE=
#DefaultLimitDATA=
#DefaultLimitSTACK=
#DefaultLimitCORE=
```

`journald.conf` offers configuration options on the journal, or logger.

# Thoughts

The declarative model of systemd emulates a "batteries included" model. It relies on integrated, homogeneous functionality in order to gain performance boosts and an encompassing feature set. Over the past few years the project has had a growing scope in the userland, as evidenced by the existance of things like the `logind.conf` and `journald.conf`, both of which used to be jobs outside of the initialization system. The regular syntax of all of these configurations does offer a boon, but at the cost of modularity and with greater complexity.

OpenRC's sysvinit based startup shows it's age, but the system's lack of opinionation offers huge benefits. With OpenRC, there is no persistent daemon, though integration with supervision tools like `s6` and `monit` exist. OpenRC also plays nice with `*cron`. Keeping itself in a limited scope, and maintaining the "Do one thing and do it well" philosophy that gave rise to the UNIX ecosystem. It has worn it's age well, however it's reliance on old assumptions about the lifecycle of a system boot limits it's capabilities.


# Further Reading

* [OpenRC Dependencies](http://www.funtoo.org/Package:OpenRC)
* [Rethinking PID 1](http://0pointer.de/blog/projects/systemd.html)
* [Red Hat: Working with systemd Targets](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/sect-Managing_Services_with_systemd-Targets.html)
* [Systemd Target](http://www.freedesktop.org/software/systemd/man/systemd.target.html)
* [Systemd status update 1](http://0pointer.de/blog/projects/systemd-update.html)
* [Systemd status update 2](http://0pointer.de/blog/projects/systemd-update-2.html)
* [Systemd status update 3](http://0pointer.de/blog/projects/systemd-update-3.html)
* [Comparison of init Systems](http://wiki.gentoo.org/wiki/Comparison_of_init_systems)
* [s6 why?](http://skarnet.org/software/s6/why.html)
* [Initscripts (Gentoo Handbook)](https://www.gentoo.org/doc/en/handbook/handbook-x86.xml?part=2&chap=4#doc_chap5)
