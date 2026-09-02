/**
 * DTest reporter — Output reporters.
 *
 * Provides:
 *   Reporter        — abstract interface
 *   ConsoleReporter — colored terminal output matching GoogleTest style
 */
module reporter;

import dtestcore   : TestCase, TestResult, Failure;
import runner : RunSummary;
import std.stdio    : writef, writefln, stdout;
import std.string   : format, rightJustify;
import std.array    : Appender, appender;
import core.time    : Duration;

// ─── Abstract Reporter ────────────────────────────────────────────────────────

abstract class Reporter
{
    TestResult[] results;  /// Accumulated; used by XML output.

    void onBeginAll(int total, int repeat) { }
    void onBeginIteration(int iter, int total) { }
    void onBeginSuite(string name) { }
    void onEndSuite(string name) { }
    void onTestStart(in TestCase tc) { }
    void onTestEnd(TestResult result)   { results ~= result; }
    void onTestSkipped(TestResult result) { results ~= result; }
    void onEndAll(RunSummary s) { }
    void onShuffle(uint seed) { }
    void onListTest(in TestCase tc) { }
}

// ─── ANSI colors ─────────────────────────────────────────────────────────────

private enum Color
{
    reset  = "\033[0m",
    red    = "\033[31m",
    green  = "\033[32m",
    yellow = "\033[33m",
    cyan   = "\033[36m",
    white  = "\033[37m",
    bold   = "\033[1m",
}

private bool _useColor;

shared static this()
{
    import std.stdio : stdout;
    version (Windows)
    {
        // Windows: check for ANSI support
        _useColor = false; // conservative; can be enabled via --dtest-color
    }
    else
    {
        import core.sys.posix.unistd : isatty, STDOUT_FILENO;
        _useColor = isatty(STDOUT_FILENO) != 0;
    }
}

private string colorize(string s, string color)
{
    return _useColor ? color ~ s ~ Color.reset : s;
}

// ─── Console Reporter ─────────────────────────────────────────────────────────

class ConsoleReporter : Reporter
{
    private bool   _brief;
    private int    _total;
    private string _currentSuite;

    this(bool brief = false) { _brief = brief; }

    override void onBeginAll(int total, int repeat)
    {
        _total = total;
        string rep = repeat > 1 ? format(" (%d times)", repeat) : "";
        writefln("%s Running %d test%s%s",
            colorize("[==========]", Color.green ~ Color.bold),
            total, total == 1 ? "" : "s", rep);
    }

    override void onBeginIteration(int iter, int total)
    {
        writefln("%s Iteration %d of %d",
            colorize("[----------]", Color.green),
            iter, total);
    }

    override void onBeginSuite(string name)
    {
        _currentSuite = name;
        if (!_brief)
            writefln("%s %s",
                colorize("[----------]", Color.green),
                colorize(name, Color.bold));
    }

    override void onEndSuite(string name)
    {
        if (!_brief)
            writefln("%s %s\n",
                colorize("[----------]", Color.green), name);
    }

    override void onTestStart(in TestCase tc)
    {
        if (!_brief)
            writef("%-12s %s ... ",
                colorize("[ RUN      ]", Color.green),
                tc.fullName);
        stdout.flush();
    }

    override void onTestEnd(TestResult result)
    {
        super.onTestEnd(result);

        string timeStr = formatDuration(result.elapsed);

        if (result.passed)
        {
            if (!_brief)
                writefln("%s (%s)",
                    colorize("[       OK ]", Color.green), timeStr);
        }
        else
        {
            if (_brief)
                writef("%-12s %s ... ", colorize("[ RUN      ]", Color.green),
                    result.fullName);

            writefln("%s (%s)",
                colorize("[  FAILED  ]", Color.red ~ Color.bold), timeStr);

            foreach (f; result.failures)
            {
                writefln("  %s:%d: %s",
                    colorize(f.file, Color.white ~ Color.bold),
                    f.line,
                    colorize(f.expression, Color.yellow));
                if (f.message.length)
                    writefln("    %s", f.message);
            }
        }
    }

    override void onTestSkipped(TestResult result)
    {
        super.onTestSkipped(result);
        string reason = result.skipReason.length
            ? " (" ~ result.skipReason ~ ")" : "";
        writefln("%-12s %s%s",
            colorize("[ DISABLED ]", Color.yellow),
            result.fullName, reason);
    }

    override void onEndAll(RunSummary s)
    {
        writefln("\n%s %d test%s ran (%s)",
            colorize("[==========]", Color.green ~ Color.bold),
            s.total, s.total == 1 ? "" : "s",
            formatDuration(s.totalElapsed));

        writefln("%s %d test%s.",
            colorize("[  PASSED  ]", Color.green),
            s.passed, s.passed == 1 ? "" : "s");

        if (s.skipped > 0)
            writefln("%s %d test%s.",
                colorize("[ DISABLED ]", Color.yellow),
                s.skipped, s.skipped == 1 ? "" : "s");

        if (s.failed > 0)
        {
            writefln("%s %d test%s, listed below:",
                colorize("[  FAILED  ]", Color.red ~ Color.bold),
                s.failed, s.failed == 1 ? "" : "s");

            foreach (r; results)
                if (!r.passed && !r.skipped)
                    writefln("  %s %s",
                        colorize("[  FAILED  ]", Color.red), r.fullName);
        }
    }

    override void onShuffle(uint seed)
    {
        writefln("Note: Test order randomised with seed %d.", seed);
    }

    override void onListTest(in TestCase tc)
    {
        writefln("%s  # %s", tc.fullName,
            tc.disabled ? "DISABLED" : "");
    }
}

// ─── Duration formatting ──────────────────────────────────────────────────────

private string formatDuration(Duration d)
{
    long ms = d.total!"msecs";
    if (ms < 1)   return "< 1 ms";
    if (ms < 1000) return format("%d ms", ms);
    return format("%.2f s", ms / 1000.0);
}
