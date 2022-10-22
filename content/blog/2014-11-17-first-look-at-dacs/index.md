+++
title = "A First Look at DACS"
aliases = ["2014/11/17/first-look-at-dacs/"]
template = "blog/single.html"
[taxonomies]
tags = [
  "UVic",
  "Tutorials",
]
+++

At Simbioses Lab, we've been recently looking at the federated authentication [DACS](http://dacs.dss.ca/) as well as [Keycloak](http://keycloak.jboss.org/). I've previously written about Keycloak, so let's take a look at DACS.

<!-- more -->

<table>
  <thead>
    <tr>
      <th>Feature</th>
      <th>Keycloak</th>
      <th>DACS</th>
    </tr>
  </thead>
  <tbody>
  	<tr>
    	<td>Author</td>
        <td><a href="http://www.redhat.com/en">Red Hat</a></td>
        <td><a href="http://www.dss.ca/">Distributed Systems Software</a></td>
    </tr>
    <tr>
      <td>License</td>
      <td><a href="https://www.apache.org/licenses/LICENSE-2.0" rel="noreferrer">ASL v2</a></td>
      <td><a href="http://dacs.dss.ca/licensing.html" rel="noreferrer">Sleepycat</a></td>
    </tr>
    <tr>
      <td>Implementation Language</td>
      <td>Java</td>
      <td>C/C++</td>
    </tr>
    <tr>
      <td>Authentication</td>
      <td>True</td>
      <td>True</td>
    </tr>
    <tr>
      <td>Authorization</td>
      <td>True</td>
      <td>True</td>
    </tr>
    <tr>
      <td>Access Control Type</td>
      <td>Role-based</td>
      <td>Role-based, Context Based</td>
    </tr>
    <tr>
      <td>Supported Languages</td>
      <td>Java, Clojure (More planned)</td>
      <td>Virtually Any (C/C++ API, Apache CGI, Java, Command Line), REST</td>
    </tr>
    <tr>
      <td>Single Sign-On</td>
      <td>Yes</td>
      <td>Yes</td>
    </tr>
    <tr>
      <td>Supported Authentication Types</td>
      <td>Password, TOTP, LDAP</td>
      <td>Unix, Password, NTLM, X.509. LDAP, CAS, TOTP</td>
    </tr>
    <tr>
      <td>Multi-Factor Authentication</td>
      <td>True</td>
      <td>True</td>
    </tr>
    <tr>
      <td>Federation</td>
      <td>False</td>
      <td>True</td>
    </tr>
    <tr>
      <td>OAuth Consumer/Client</td>
      <td>True</td>
      <td>Partial</td>
    </tr>
    <tr>
      <td>OAuth Provider/Server</td>
      <td>False</td>
      <td>Planned</td>
    </tr>
    <tr>
      <td>Stateless (Cookie-free) Operation</td>
      <td>False</td>
      <td>True</td>
    </tr>
    <tr>
      <td>OpenID Support</td>
      <td>True</td>
      <td>Planned</td>
    </tr>
    <tr>
      <td>Browser Based Administration</td>
      <td>False</td>
      <td>Partial</td>
    </tr>
    <tr>
      <td>Command Line Interface</td>
      <td>Partial</td>
      <td>True</td>
    </tr>
  </tbody>
</table>

## DACS Sample Deployments

* [National Forest Information System](http://www.nfis.org/)
* [Debian Single Sign-On](https://wiki.debian.org/DebianSingleSignOn)

## DACS Install

We'll try using [Ubuntu's stable package](https://launchpad.net/ubuntu/+source/dacs) available in the repositories.

    sudo apt-get install dacs

A quick test reveals several `dacs` related binaries are now available.

    dacsacl        dacs_acs
    dacsauth       dacscheck
    dacsconf       dacscookie
    dacscred       dacsemail
    dacsexpr       dacsgrid
    dacshttp       dacsinfocard
    dacskey        dacslist
    dacspasswd     dacsrlink
    dacssched      dacstoken
    dacstransform  dacsversion
    dacsvfs

Since `dacsinit` is not available in this package, we'll need to configure the system manually. By default this package installs the configuration directories to `/etc/dacs` with `root:root` permissions.


    dacsgroup=root
    dacs=/etc/dacs
    feds=$dacs/federations
    la=$feds/dacstest.dss.ca/LA
    install -c -g $dacsgroup -m 0640 $feds/site.conf-std $feds.site.conf
    install -c -g $dacsgroup -m 0660 /dev/null $feds/dacs.conf
    install -d -g $dacsgroup -m 0770 $feds/dacstest.dss.ca
    install -d -g $dacsgroup -m 0770 $la
    install -d -g $dacsgroup -m 0770 $la/acls
    install -c -g $dacsgroup -m 6660 /dev/null $la/acls/revocations
    install -d -g $dacsgroup -m 0770 $la/groups $la/groups/LA $la/groups/DACS
    install -c -g $dacsgroup -m 0660 /dev/null $la/groups/DACS/jurisdictions.grp

In the `$la/groups/DACS/jurisdictions.grp`:

    <groups xmlns="http://dss.ca/dacs/v1.4">
     <group_definition jurisdiction="LA" name="jurisdictions"
         mod_date="Tue, 14-Jun-2005 16:06:00 GMT" type="public">
       <group_member jurisdiction="LA" name="LA Jurisdiction" type="meta"
         alt_name="Test Jurisdiction for the LA Dodgers"
         dacs_url="http://dodgers.dacstest.dss.ca:18123/cgi-bin/dacs"
         authenticates="yes" prompts="no"/>
     </group_definition>
    </groups>

In `$feds/dacs.conf`:


    <Configuration xmlns="http://dss.ca/dacs/v1.4">

     <Default>
       FEDERATION_DOMAIN "dacstest.dss.ca"
       FEDERATION_NAME "DACSTEST"
       LOG_LEVEL "info"
     </Default>

     <Jurisdiction uri="dodgers.dacstest.dss.ca">
       JURISDICTION_NAME "LA"
     </Jurisdiction>

    </Configuration>

Then set the configuration:

    rm -f $la/dacs.conf
    ln -s $feds/dacs.conf $la/dacs.conf

Next we can check the configuration with:

    dacsconf -uj LA -q

It should output a set of variables like so:

    …
    ALLOW_HTTP_COOKIE "no"
    AUTH_FAIL_DELAY_SECS "2"
    ACS_ERROR_HANDLER "* /handlers/acs_failed.html"
    SECURE_MODE "on"
    COOKIE_PATH "/"
    …

Next, we need to set up the federation keys.

    install -c -g $dacsgroup -m 0640 /dev/null $feds/dacstest.dss.ca/federation_keyfile
    dacskey -uj LA -q $feds/dacstest.dss.ca/federation_keyfile

## DACS Authentication

> If you're following along with me, these commands may require `sudo` because of how we set up permissions.

First, lets add a `passwd` file. The identities managed by this file are not related to the local UNIX users.

    install -c -g $dacsgroup -m 0660 /dev/null $la/passwd
    dacspasswd -uj LA -q -a bear
    # Give them password `bear`

Then add to the **Jurisdiction** section of `$la/dacs.conf`:

    <Auth id="passwd">
       URL "http://dodgers.dacstest.dss.ca:18123/cgi-bin/dacs/local_passwd_authenticate"
       STYLE "pass"
       CONTROL "sufficient"
    </Auth>

Now try authenticating with:

    dacsauth -m passwd passwd required -vfs "[passwds]dacs-kwv-fs:/etc/dacs/federations/dacstest.dss.ca/LA/passwd" -q -u bear -p bear
    echo $?
    # 0 means success.

Now lets make it fail:

    dacsauth -m passwd passwd required -vfs "[passwds]dacs-kwv-fs:/etc/dacs/federations/dacstest.dss.ca/LA/passwd" -q -u bear -p bears
    echo $?
    # 1 means failure.

> The `-vfs` flag is important, it tells DACS where to look for the respective files.

Authenticating as a UNIX user:

    useradd bear
    passwd bear # Set it to foo
    dacsauth -m unix passwd required -u bear -p foo
    echo $? # 0 means success.
    dacsauth -m unix passwd required -u bear -p bar
    echo $? # 1 means failure.

## DACS Roles

If authenticating as a UNIX user, roles in DACS are based upon the groups the user is in. For example:

    dacsauth -r unix -u bear
    # Outputs 'bear'

    gpasswd -a users bear

    dacsauth -r unix -u bear
    # Outputs 'bear,users'

To add roles to a DACS user, we can consult [the relevant documentation](http://dacs.dss.ca/man/dacs_authenticate.8.html#local_roles) which directs us to create a `/etc/dacs/federations/roles` file with contents like the following:

    bear:animals,mammals

Now we can check DACS for the roles of our user:

    dacsauth -r roles -vfs "[roles]dacs-kwv-fs:/etc/dacs/federations/roles" -u bear
    # animals,mammals

You may notice other output when issuing these commands, but note they are on `stderr`, not `stdout`.

# Interfacing with DACS

Since we've explored two common use cases for DACS, authentication and role checking. Lets look like how doing this would look from two languages, Javascript (Node) and Rust.

## Authentication
In Javascript, it's easy to just use the `child_process` built-in library. These examples are structured such that they would fit nicely into a middleware based system like used in `express`:

    /**
     * Uses DACS' local module.
     * Determines whether the login details are valid.
     * @param  {String}   user The username string.
     * @param  {String}   pass The password string.
     * @param  {Function} next The callback, signature (error, worked).
     */
    function localAuth(user, pass, next) {
        var exec = require('child_process').exec,
            module_opts = '-m passwd passwd required',
            vfs_opts = '-vfs "[passwds]dacs-kwv-fs:/etc/dacs/federations/dacstest.dss.ca/LA/passwd"',
            login_opts = '-u ' + user + ' -p ' + pass,
            command = ['dacsauth', module_opts, vfs_opts, login_opts].join(' ');

        var dacsauth = exec(command, function (err, stdout, stderr) {
            if (err !== null) {
                // The status code is not 0.
                next(err, false);
            } else {
                next(null, true);
            }
        });
    }

    (function testLocalAuth() {
        localAuth('bear', 'bear', function output(err, worked) {
            if (worked) {
                console.log('LOCAL: Successfully authenticated as `bear`');
            } else {
                console.log('LOCAL: Failed to authenticate');
                console.error(err);
            }
        });
    }());

    /**
     * Uses the `unix` module.
     * Determines whether the login details are valid.
     * @param  {String}   user The username string.
     * @param  {String}   pass The password string.
     * @param  {Function} next The callback, signature (error, worked).
     */
    function unixAuth(user, pass, next) {
        var exec = require('child_process').exec,
            module_opts = '-m unix passwd required',
            login_opts = '-u ' + user + ' -p ' + pass,
            command = ['dacsauth', module_opts, login_opts].join(' ');

        var dacsauth = exec(command, function (err, stdout, stderr) {
            if (err !== null) {
                // The status code is not 0.
                next(err, false);
            } else {
                next(null, true);
            }
        });
    }

    (function testUnixAuth() {
        unixAuth('bear', 'foo', function output(err, worked) {
            if (worked) {
                console.log('UNIX: Successfully authenticated as `bear`');
            } else {
                console.log('UNIX: Failed to authenticate');
                console.error(err);
            }
        });
    }());

Running it:

    node test.js
    # LOCAL: Successfully authenticated as `bear`
    # UNIX: Successfully authenticated as `bear`

In Rust, this task is also simple enough by using `Command`, which I've written about [here](http://www.hoverbear.org/2014/09/07/command-execution-in-rust/) (Note it is slightly out of date):

    use std::io::Command;
    use std::io::process::ProcessExit::ExitStatus;

    /// Uses DACS' local module.
    /// Determines whether the login details are valid.
    fn local_auth(user: &str, pass: &str) -> bool {
        let opts = [
            // Module Opts
            "-m", "passwd", "passwd", "required",
            // VFS Opts
            "-vfs", "[passwds]dacs-kwv-fs:/etc/dacs/federations/dacstest.dss.ca/LA/passwd",
            // Login Opts
            "-u", user, "-p", pass,
        ];
        let status = Command::new("dacsauth").args(&opts).status();
        match status {
            Ok(ExitStatus(code)) if code == 0 => true,
            _ => false
        }
    }

    #[test]
    fn test_local_auth() {
        assert!(local_auth("bear", "bear") == true);
        assert!(local_auth("bear", "bears") == false);
    }

    /// Uses the `unix` module.
    /// Determines whether the login details are valid.
    fn unix_auth(user: &str, pass: &str) -> bool {
        let opts = [
            // Module Opts
            "-m", "unix", "passwd", "required",
            // Login Opts
            "-u", user, "-p", pass,
        ];
        let status = Command::new("dacsauth").args(&opts).status();
        match status {
            Ok(ExitStatus(status)) if status == 0 => true,
            _ => false
        }
    }

    #[test]
    fn test_unix_auth() {
        assert!(unix_auth("bear", "foo") == true);
        assert!(unix_auth("bear", "bar") == false);
    }

Running it:

    rustc test.rs --test
    ./test
    # running 2 tests
    # test test_local_auth ... ok
    # test test_unix_auth ... ok
    #
    # test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured

## Roles

Using a similar style of code, we can get the roles for a user like so:

    /**
    * Uses DACS' local module.
    * Determines the user's roles.
    * @param  {String}   user The username string.
    * @param  {Function} next The callback, signature (error, roles).
    */
    function localRoles(user, next) {
        var exec = require('child_process').exec,
        module_opts = '-r roles',
        vfs_opts = '-vfs "[roles]dacs-kwv-fs:/etc/dacs/federations/roles"',
        login_opts = '-u ' + user,
        command = ['dacsauth', module_opts, vfs_opts, login_opts].join(' ');

        var dacsauth = exec(command, function (err, stdout, stderr) {
            if (err !== null) {
                // The status code is not 0.
                next(err, stdout.trim().split(','));
            } else {
                next(null, stdout.trim().split(','));
            }
        });
    }

    (function testLocalRoles() {
        localRoles('bear', function output(err, roles) {
            if (roles) {
                console.log('LOCAL: `bear` has roles ' + roles);
            } else {
                console.log('LOCAL: Failed to get roles');
                console.error(err);
            }
        });
    }());

    /**
    * Uses the `unix` module.
    * Determines the user's roles.
    * @param  {String}   user The username string.
    * @param  {Function} next The callback, signature (error, roles).
    */
    function unixRoles(user, next) {
        var exec = require('child_process').exec,
        module_opts = '-r unix',
        login_opts = '-u ' + user,
        command = ['dacsauth', module_opts, login_opts].join(' ');

        var dacsauth = exec(command, function (err, stdout, stderr) {
            if (err !== null) {
                // The status code is not 0.
                next(err, stdout.trim().split(','));
            } else {
                next(null, stdout.trim().split(','));
            }
        });
    }

    (function testUnixRoles() {
        unixRoles('bear', function output(err, roles) {
            if (roles) {
                console.log('UNIX: `bear` has roles ' + roles);
            } else {
                console.log('UNIX: Failed to get roles');
                console.error(err);
            }
        });
    }());

Running it:

    nodejs test.js
    # LOCAL: `bear` has roles animals,mammals
    # UNIX: `bear` has roles bear,users

And in Rust:

    use std::io::Command;
    use std::str;

    /// Uses DACS' local module.
    /// Determines the user's roles.
    fn local_roles(user: &str) -> Vec<String> {
        let opts = [
            // Module Opts
            "-r", "roles",
            // VFS Opts
            "-vfs", "[roles]dacs-kwv-fs:/etc/dacs/federations/roles",
            // Login Opts
            "-u", user
        ];
        let result = Command::new("dacsauth").args(&opts).output()
            .ok().expect("Could not get output.");
        let stdout = str::from_utf8(result.output.as_slice())
            .expect("Could not parse stdout.");
        stdout.trim_chars('\n').split(',')
            .map(|x| String::from_str(x))
            .filter(|x| x.len() != 0) // Handle the empty string.
            .collect()
    }

    #[test]
    fn test_local_roles() {
        assert!(local_roles("bear") == vec!["animals".to_string(), "mammals".to_string()]);
        assert!(local_roles("invalid") == Vec::<String>::new());
    }

    /// Uses the `unix` module.
    /// Determines the user's roles.
    fn unix_roles(user: &str) -> Vec<String> {
        let opts = [
            // Module Opts
            "-r", "unix",
            // Login Opts
            "-u", user
        ];
        let result = Command::new("dacsauth").args(&opts).output()
            .ok().expect("Could not get output.");
        let stdout = str::from_utf8(result.output.as_slice())
            .expect("Could not parse stdout.");
        stdout.trim_chars('\n').split(',')
            .map(|x| String::from_str(x))
            .filter(|x| x.len() != 0) // Handle the empty string.
            .collect()
    }

    #[test]
    fn test_unix_roles() {
        assert!(unix_roles("bear") == vec!["bear".to_string(), "users".to_string()]);
        assert!(unix_roles("invalid") == Vec::<String>::new());
    }

Running it:

    rustc test.rs --test
    ./test
    # running 2 tests
    # test test_local_roles ... ok
    # test test_unix_roles ... ok
    #
    # test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured

## Thoughts on DACS

DACS is, overall, effective at the tasks it claims to accomplish. It is flexible with where it's configuration is stored, how it is invoked, and which components it is compiled with.

When I was first compiling this article, I attempted to compile DACS from source (as suggested in both the [Install](http://dacs.dss.ca/man/dacs.install.7.html) and [Quick Install](http://dacs.dss.ca/man/dacs.quick.7.html) guides). I was concerned with the fact that the guide suggests you do things like compile your own versions of things like OpenSSL and Apache from source instead of from your distributions packages. OpenSSL and Apache are both critical packages for a server, and should be handled with care. Recall things like [Shellshock](http://en.wikipedia.org/wiki/Shellshock_%28software_bug%29) (which effected Apache's CGI) and [Heartbleed](http://en.wikipedia.org/wiki/Heartbleed) (which effected [OpenSSL](http://opensslrampage.org/) and prompted the creation of [LibreSSL](http://www.libressl.org/)). I ended up using the packages available on [Ubuntu](http://packages.ubuntu.com/trusty/dacs) as the [Debian](https://packages.debian.org/sid/dacs) packages were quite out of date in stable.

The DACS documentation is quite complete and covers a wide range of topics, which makes sense given DACS's wide scope. For a newcomer to DACS, however, they are quite opaque due to their self referencing and assumption of inherant knowledge regarding the application. Questions like "Where is the normal place to store a roles file?" and "What are the various `[foo]` fields for the `-vfs` flag?" were challenging to find answers to. This is understandable for a complex system that has limited usage, but at some points it felt like th documentation was written by DACS programmers, for DACS programmers, instead of DACS users.

## Further Exploration

DACS has a variety of features, such Apache integration (for CGI applications), Federation support, Groups, adapters for LDAP, etc.  I haven't dug into them here because they're more involved and will only be applicable in more complex scenarios, in which case, the implementor should become familiar with the documentation of DACS itself, rather then a whirlwind tour like this article.

## DACS Documentation

* [dacsauth](dacs.dss.ca/man/dacsauth.1.html)
* [Installing DACS](http://dacs.dss.ca/man/dacs.install.7.html) *(Note this is from source)*
* [DACS VFS](http://dacs.dss.ca/man/dacs.vfs.5.html)
