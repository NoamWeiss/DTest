# Security Policy

## Reporting a vulnerability

Please do not open a public issue for security problems.

Use GitHub's private vulnerability reporting instead:
**Security → Report a vulnerability** on the
[DTest repository](https://github.com/NoamWeiss/DTest/security/advisories/new).

Include what you found, how to reproduce it, and the impact you expect.
You should hear back within a week. Once a fix is available it will be
released and the advisory published with credit to the reporter, unless
you prefer to stay anonymous.

## Scope

DTest is a unit-testing library that runs your own test code in your own
process. Issues of interest include anything that lets a test file or a
command-line flag do something unexpected outside the test run, for
example path handling in the `--dtest-xml` report writer or the death-test
child process machinery.

## Supported versions

Only the latest commit on `master` receives fixes.
