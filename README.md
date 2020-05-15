PCC2/PCC2ng/PlanetsCentral System Tests
=======================================

This folder contains system tests for PCC2/PCC2ng/PlanetsCentral.
System tests are:

- testing a binary's command-line interface
- testing a microservice's network interface
- testing a CGI script within a possibly synthetic environment

In addition to testing the PCC2ng implementation, one major objective
of these tests is to allow functional tests comparing the "ng"
implementation against the "classic" implementation.


Tests
-----

Tests are written in Perl, using a common library `c2systest.pm`. Web
tests additionally use `c2cgitest.pm`, some common initialisations for
microservices are collected in `c2service.pm`.

Tests are grouped in subdirectories, each named after the service it
tests (i.e. `talk` tests the `c2talk` server). The `web` directory
contains tests for the website (CGI scripts), the `self` directory
contains tests testing the test framework itself.

Tests fall into three categories:

- regular tests, named `NN_XXX.pl`. Invoking the top-level `test.pl`
  without parameters will run all these.
- slow tests, named `xNN_XXX.pl`. Those are only run when requested
  explicitly because they can take long.
- performance test, named `pNN_XXX.pl`. Those are also only run when
  requested explicitly, because they can take long. Their result is
  not only a SUCCESS/FAILURE, but also a performance metric. Invoking
  the top-level `test.pl` with the `--perf` parameter will run these.

The `NN` is a number just to provide an ordering for the tests but is
not otherwise important. It makes sense to sort tests first that
detect easy common failures such as misconfiguration. Otherwise,
conventions are:

- `50_xxx`: equivalent to a unit test in c2ng
- `90_NNN_xxx`: test case for bug NNN

Folder `interactive` contains tests that set up an environment and
serve it via HTTP, for interactive testing with a browser.


Configuring
-----------

Main configuration is through a file `system.conf`.

* `afl`, `c2ng`, `c2web`, `c2server`

  Directories for the respective projects

* `PROG.path`

  Name of the respective program.

Values can include references to other variables (`$(c2ng)`), which
are resolved when the value is used.

Changing the `PROG.path` options allows to test any configuration of
microservices (classic vs. ng). The core module `c2systest.pm`
implements a few adaptions:

* Command-line parameters of c2file differ between classic and ng.
  This is handled by `setup_add_userfile` and `setup_add_hostfile`
  which let ng to run on internal storage instead of temporary files.
  They also include an option `auto` to always use temporary files,
  for testing with an application that needs to share the filespace
  (c2host classic).

* `respserver.path` normally points at the `afl` respserver example.
  If it points at `redis-server` instead, that one is configured and
  used.


Running Tests
-------------

Each test can be run individually and accepts the following
parameters:

* `-DKEY=VALUE`

  Override a name from the system configuration file.

* `--config=FILE`

  Change the name of the system configuration file.

  Default: `system.conf`

* `--color`, `--no-color`

  Enable or disable use or colors in messages.

  Default: enabled when stdout is a terminal.

* `-v`

  Increase verbosity. Add multiple times to make even more verbose.

  - `-v`: show programs being run
  - `-vv`: show output of programs
  - `-vvv`: show creation of major objects within the test
  - `-vvvv`: show more details

* `-q`

  Decrease verbosity (cancels `-v`).

* `--debug`

  Enable ad-hoc internal debugging functionality.

To run multiple tests in a row, you can use `test.pl`. By default, it
runs all standard tests. If test file names are given on the command
line, those are run instead.

`test.pl` accepts all options accepted by individual tests and passes
these along. In addition, it accepts:

* `-k`

  Keep going after a test fails. By default, aborts on first failure.

* `--perf`

  Run performance tests. Only effective when no test names are given
  on the command line; instead of the standard tests, runs the
  performance tests.
