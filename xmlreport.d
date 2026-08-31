/**
 * dtest.xmlreport — JUnit-compatible XML output (--dtest-xml).
 *
 * Produces a file that CI systems (Jenkins, GitHub Actions, etc.) can ingest.
 */
module xmlreport;

import dtestcore   : TestResult, Failure;
import std.stdio    : File;
import std.string   : format, replace;
import std.algorithm : filter, map, sum;
import std.array    : array;

void writeXML(string path, TestResult[] results)
{
    auto f = File(path, "w");
    scope(exit) f.close();

    int total   = cast(int) results.length;
    int failures = cast(int) results.filter!(r => !r.passed && !r.skipped).array.length;
    int skipped  = cast(int) results.filter!(r => r.skipped).array.length;
    long ms = results.map!(r => r.elapsed.total!"msecs").sum;

    f.writefln(`<?xml version="1.0" encoding="UTF-8"?>`);
    f.writefln(`<testsuites tests="%d" failures="%d" disabled="%d" time="%.3f">`,
        total, failures, skipped, ms / 1000.0);

    // Group by suite
    string currentSuite = null;
    foreach (r; results)
    {
        if (r.suiteName != currentSuite)
        {
            if (currentSuite !is null)
                f.writeln(`  </testsuite>`);
            currentSuite = r.suiteName;
            f.writefln(`  <testsuite name="%s">`, xmlEscape(r.suiteName));
        }

        long rms = r.elapsed.total!"msecs";
        f.writef(`    <testcase name="%s" classname="%s" time="%.3f"`,
            xmlEscape(r.testName), xmlEscape(r.suiteName), rms / 1000.0);

        if (r.skipped)
        {
            f.writeln(`>`);
            f.writefln(`      <skipped message="%s"/>`, xmlEscape(r.skipReason));
            f.writeln(`    </testcase>`);
        }
        else if (!r.passed)
        {
            f.writeln(`>`);
            foreach (fail; r.failures)
            {
                f.writefln(`      <failure message="%s" type="AssertionFailure">`,
                    xmlEscape(fail.expression));
                f.writefln(`        %s:%d: %s`,
                    xmlEscape(fail.file), fail.line, xmlEscape(fail.message));
                f.writeln(`      </failure>`);
            }
            f.writeln(`    </testcase>`);
        }
        else
        {
            f.writeln(`/>`);
        }
    }

    if (currentSuite !is null)
        f.writeln(`  </testsuite>`);

    f.writeln(`</testsuites>`);
}

private string xmlEscape(string s)
{
    return s
        .replace("&",  "&amp;")
        .replace("<",  "&lt;")
        .replace(">",  "&gt;")
        .replace(`"`,  "&quot;")
        .replace("'",  "&apos;");
}
