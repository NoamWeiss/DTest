/**
 * dtest.core — Test registration, discovery, and core data structures.
 *
 * Provides:
 *   - TestCase / TestResult structs
 *   - Global test registry
 *   - TEST()  mixin — plain test (analogous to gtest TEST)
 *   - TEST_F() mixin — fixture-based test (analogous to gtest TEST_F)
 *   - TEST_DISABLED() mixin — skipped test
 */
module dtestcore;

import std.stdio;
import std.string : format;
import std.array : Appender, appender;
import std.algorithm : canFind;
import core.time : Duration, MonoTime;

// ─── Failure record ──────────────────────────────────────────────────────────

/// A single assertion failure captured during a test run.
struct Failure
{
    string file;
    size_t line;
    string expression; /// The assertion expression text
    string message;    /// Optional user-supplied message
    bool   fatal;      /// ASSERT_* vs EXPECT_*
}

// ─── Test result ─────────────────────────────────────────────────────────────

/// The result of running one test case.
struct TestResult
{
    string    suiteName;
    string    testName;
    bool      passed;
    bool      skipped;
    Duration  elapsed;
    Failure[] failures;
    string    skipReason;

    string fullName() const { return suiteName ~ "." ~ testName; }
}

// ─── Test case descriptor ─────────────────────────────────────────────────────

alias TestFn = void delegate();

struct TestCase
{
    string   suiteName;
    string   testName;
    TestFn   fn;
    bool     disabled;
    string   disabledReason;

    string fullName() const { return suiteName ~ "." ~ testName; }
}

// ─── Global registry ─────────────────────────────────────────────────────────

private __gshared TestCase[] _registry;
private __gshared Object     _registryLock;

shared static this()
{
    _registryLock = new Object();
}

/// Register a test case. Called automatically by TEST / TEST_F mixins.
void registerTest(TestCase tc) @trusted
{
    synchronized (_registryLock)
        _registry ~= tc;
}

/// Return a snapshot of all registered tests (optionally filtered).
TestCase[] allTests() @trusted
{
    synchronized (_registryLock)
        return _registry.dup;
}

// ─── Thread-local failure sink ────────────────────────────────────────────────

/// Failures accumulated by the currently-running test.
package Appender!(Failure[]) _currentFailures;
package bool                  _fatalFired;

void resetTestState()
{
    _currentFailures = appender!(Failure[])();
    _fatalFired = false;
}

void recordFailure(Failure f)
{
    _currentFailures.put(f);
    if (f.fatal)
        _fatalFired = true;
}

bool hasFatalFailure() { return _fatalFired; }
Failure[] currentFailures() { return _currentFailures.data.dup; }

// ─── Fatal-failure exception (ASSERT_ path) ───────────────────────────────────

class FatalFailureException : Exception
{
    this() { super("Fatal assertion failed"); }
}

// ─── TEST() mixin ─────────────────────────────────────────────────────────────

/**
 * Declare a plain test.
 *
 * Usage:
 * ---
 * mixin TEST!("MathSuite", "AddsTwoNumbers")
 * {
 *     EXPECT_EQ(1 + 1, 2);
 * }
 * ---
 */
mixin template TEST(string Suite, string Name, string _code)
{
    mixin(`
    private void _body_` ~ Suite ~ `_` ~ Name ~ `() {
        ` ~ _code ~ `
    }

    shared static this()
    {
        import dtestcore : TestCase, registerTest;
        registerTest(TestCase(
            "` ~ Suite ~ `",
            "` ~ Name ~ `",
            () { _body_` ~ Suite ~ `_` ~ Name ~ `(); },
            false, ""
        ));
    }
    `);
}

// ─── TEST_DISABLED() mixin ────────────────────────────────────────────────────

/**
 * Declare a test that is registered but skipped.
 *
 * Usage:
 * ---
 * mixin TEST_DISABLED!("MathSuite", "NotImplementedYet", "TODO: implement")
 * {
 *     // body is never executed
 * }
 * ---
 */
mixin template TEST_DISABLED(string Suite, string Name, string Reason = "", string _code = "")
{
    mixin(`
    shared static this()
    {
        import dtestcore : TestCase, registerTest;
        registerTest(TestCase(
            "` ~ Suite ~ `",
            "DISABLED_` ~ Name ~ `",
            () {},
            true, "` ~ Reason ~ `"
        ));
    }
    `);
}

// ─── TEST_F() mixin ───────────────────────────────────────────────────────────

/**
 * Declare a fixture-based test.
 *
 * The fixture class must extend `dtest.fixture.TestFixture` and be in scope.
 *
 * Usage:
 * ---
 * class MyFixture : TestFixture
 * {
 *     int value;
 *     override void setUp()    { value = 42; }
 *     override void tearDown() { }
 * }
 *
 * mixin TEST_F!("MyFixture", "UsesValue")
 * {
 *     EXPECT_EQ(fixture.value, 42);
 * }
 * ---
 *
 * Inside the body, `fixture` refers to the freshly-constructed fixture instance.
 */
mixin template TEST_F(string FixtureClass, string Name, string _code)
{
    mixin(`
    private void _body_fixture_` ~ FixtureClass ~ `_` ~ Name ~ `(` ~ FixtureClass ~ ` fixture) {
        ` ~ _code ~ `
    }

    shared static this()
    {
        import dtestcore    : TestCase, registerTest;
        import fixture : runFixtureTest;
        registerTest(TestCase(
            "` ~ FixtureClass ~ `",
            "` ~ Name ~ `",
            () {
                runFixtureTest!` ~ FixtureClass ~ `(
                    (` ~ FixtureClass ~ ` f) {
                        _body_fixture_` ~ FixtureClass ~ `_` ~ Name ~ `(f);
                    }
                );
            },
            false, ""
        ));
    }
    `);
}
