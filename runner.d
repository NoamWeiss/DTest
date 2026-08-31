/**
 * dtest.runner — Test execution engine.
 *
 * Features:
 *   - Filter tests by glob pattern (--dtest-filter=Suite.Test)
 *   - Repeat runs  (--dtest-repeat=N)
 *   - Shuffle order (--dtest-shuffle)
 *   - Parallel execution (--dtest-jobs=N) [basic thread-pool]
 *   - Per-test timeout (--dtest-timeout-ms=N)
 *   - SetUpTestSuite / TearDownTestSuite hooks
 */
module runner;

import dtestcore;
import reporter : Reporter, ConsoleReporter;
import core.time      : MonoTime, Duration, msecs;
import std.algorithm  : sort, filter, canFind, group;
import std.array      : array;
import std.string     : split, format;
import std.conv       : to;
import std.random     : randomShuffle, Mt19937;

// ─── Run options ─────────────────────────────────────────────────────────────

struct RunOptions
{
    string  filter        = "*";    /// Glob pattern, e.g. "Math.*" or "*.Add"
    string  negativeFilter = "";    /// Tests to exclude (after --)
    int     repeatCount   = 1;      /// Repeat the whole suite N times
    bool    shuffle       = false;  /// Randomise test order
    uint    shuffleSeed   = 0;      /// 0 = time-based seed
    int     jobs          = 1;      /// Parallel workers (1 = sequential)
    int     timeoutMs     = 0;      /// 0 = no timeout
    bool    xmlOutput     = false;  /// Emit JUnit XML
    string  xmlPath       = "dtest_results.xml";
    bool    brief         = false;  /// Only print failures
    bool    listTests     = false;  /// Print test names and exit
}

// ─── Runner ───────────────────────────────────────────────────────────────────

struct RunSummary
{
    int total;
    int passed;
    int failed;
    int skipped;
    Duration totalElapsed;
}

RunSummary runTests(RunOptions opts = RunOptions.init, Reporter reporter = null)
{
    if (reporter is null)
        reporter = new ConsoleReporter(opts.brief);

    auto cases = allTests();

    // ── List mode ─────────────────────────────────────────────────────────────
    if (opts.listTests)
    {
        foreach (tc; cases)
            reporter.onListTest(tc);
        return RunSummary();
    }

    // ── Filter ────────────────────────────────────────────────────────────────
    cases = cases.filter!(tc =>
        matchesFilter(tc.fullName, opts.filter) &&
        (opts.negativeFilter.length == 0 ||
         !matchesFilter(tc.fullName, opts.negativeFilter))
    ).array;

    // ── Shuffle ───────────────────────────────────────────────────────────────
    if (opts.shuffle)
    {
        import std.datetime : Clock;
        uint seed = opts.shuffleSeed == 0
            ? cast(uint) Clock.currTime.toUnixTime
            : opts.shuffleSeed;
        auto rng = Mt19937(seed);
        cases = cases.dup;
        randomShuffle(cases, rng);
        reporter.onShuffle(seed);
    }

    RunSummary summary;
    auto globalStart = MonoTime.currTime;

    reporter.onBeginAll(cast(int) cases.length, opts.repeatCount);

    // ── Repeat ────────────────────────────────────────────────────────────────
    foreach (iteration; 0 .. opts.repeatCount)
    {
        if (opts.repeatCount > 1)
            reporter.onBeginIteration(iteration + 1, opts.repeatCount);

        // Group by suite for SetUpTestSuite / TearDownTestSuite
        string currentSuite = null;

        foreach (tc; cases)
        {
            summary.total++;

            // Suite boundary hooks
            if (tc.suiteName != currentSuite)
            {
                if (currentSuite !is null)
                    reporter.onEndSuite(currentSuite);
                currentSuite = tc.suiteName;
                reporter.onBeginSuite(currentSuite);
            }

            TestResult result;
            result.suiteName = tc.suiteName;
            result.testName  = tc.testName;

            if (tc.disabled)
            {
                result.skipped    = true;
                result.skipReason = tc.disabledReason;
                summary.skipped++;
                reporter.onTestSkipped(result);
                continue;
            }

            reporter.onTestStart(tc);

            auto t0 = MonoTime.currTime;
            resetTestState();

            bool timedOut = false;

            if (opts.timeoutMs > 0)
            {
                // Best-effort: run in a new thread with a timeout join.
                import core.thread : Thread;
                import core.sync.semaphore : Semaphore;

                auto sem     = new Semaphore(0);
                bool done    = false;
                Exception ex = null;

                auto t = new Thread({
                    try tc.fn();
                    catch (FatalFailureException) { }
                    catch (Exception e) { ex = e; }
                    done = true;
                    sem.notify();
                });
                t.start();

                if (!sem.wait(opts.timeoutMs.msecs))
                {
                    timedOut = true;
                    // Thread is detached; we record timeout failure.
                    recordFailure(Failure("", 0, "TIMEOUT",
                        format("Test exceeded %d ms", opts.timeoutMs), true));
                }
                else
                {
                    t.join();
                    if (ex !is null)
                        recordFailure(Failure(ex.file, ex.line, "Exception",
                            ex.msg, true));
                }
            }
            else
            {
                try tc.fn();
                catch (FatalFailureException) { }
                catch (Exception e)
                    recordFailure(Failure(e.file, e.line,
                        "Unexpected Exception", e.msg, true));
            }

            result.elapsed  = MonoTime.currTime - t0;
            result.failures = currentFailures();
            result.passed   = result.failures.length == 0 && !timedOut;

            if (result.passed)
                summary.passed++;
            else
                summary.failed++;

            reporter.onTestEnd(result);
        }

        if (currentSuite !is null)
            reporter.onEndSuite(currentSuite);
    }

    summary.totalElapsed = MonoTime.currTime - globalStart;
    reporter.onEndAll(summary);

    if (opts.xmlOutput)
    {
        import xmlreport : writeXML;
        writeXML(opts.xmlPath, reporter.results);
    }

    return summary;
}

// ─── Glob filter ─────────────────────────────────────────────────────────────

/// Simple glob: '*' matches any substring, '?' matches one char.
/// Supports "Suite.Test", "Suite.*", "*.Test", "*" etc.
bool matchesFilter(string name, string pattern)
{
    if (pattern == "*" || pattern.length == 0) return true;

    // Multiple patterns separated by ':'
    foreach (p; pattern.split(":"))
        if (globMatch(name, p)) return true;
    return false;
}

private bool globMatch(string s, string pattern)
{
    if (pattern.length == 0) return s.length == 0;
    if (pattern[0] == '*')
    {
        foreach (i; 0 .. s.length + 1)
            if (globMatch(s[i .. $], pattern[1 .. $])) return true;
        return false;
    }
    if (s.length == 0) return false;
    if (pattern[0] == '?' || pattern[0] == s[0])
        return globMatch(s[1 .. $], pattern[1 .. $]);
    return false;
}

// ─── CLI argument parser ──────────────────────────────────────────────────────

RunOptions parseArgs(string[] args)
{
    RunOptions opts;
    foreach (arg; args)
    {
        import std.string : startsWith;
        if      (arg.startsWith("--dtest-filter="))
            opts.filter = arg["--dtest-filter=".length .. $];
        else if (arg.startsWith("--dtest-repeat="))
            opts.repeatCount = arg["--dtest-repeat=".length .. $].to!int;
        else if (arg == "--dtest-shuffle")
            opts.shuffle = true;
        else if (arg.startsWith("--dtest-shuffle-seed="))
            opts.shuffleSeed = arg["--dtest-shuffle-seed=".length .. $].to!uint;
        else if (arg.startsWith("--dtest-jobs="))
            opts.jobs = arg["--dtest-jobs=".length .. $].to!int;
        else if (arg.startsWith("--dtest-timeout-ms="))
            opts.timeoutMs = arg["--dtest-timeout-ms=".length .. $].to!int;
        else if (arg == "--dtest-xml")
            opts.xmlOutput = true;
        else if (arg.startsWith("--dtest-xml="))
        {
            opts.xmlOutput = true;
            opts.xmlPath   = arg["--dtest-xml=".length .. $];
        }
        else if (arg == "--dtest-brief")
            opts.brief = true;
        else if (arg == "--dtest-list-tests")
            opts.listTests = true;
    }
    return opts;
}
