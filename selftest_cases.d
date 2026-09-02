/**
 * Self-tests for DTest — compiled in as part of the selftest configuration.
 */
module selftest_cases;

import dtestcore    : resetTestState, currentFailures, Failure,
                       FatalFailureException;
import assert_;
import fixture : TestFixture;
import runner  : matchesFilter;

import dtestcore : TEST, TEST_F;

// ── Assertion recording ───────────────────────────────────────────────────────

mixin TEST!("AssertInternals", "ExpectEQ_PassDoesNotRecord", q{
    resetTestState();
    EXPECT_EQ(1, 1);
    EXPECT_EQ(currentFailures().length, 0UL);
});

mixin TEST!("AssertInternals", "ExpectEQ_FailRecords", q{
    resetTestState();
    try { EXPECT_EQ(1, 2); } catch (Exception) { }
    auto f = currentFailures();
    size_t len = f.length;
    bool isFatal = f[0].fatal;
    resetTestState();  // clear intentional failure before our assertions
    EXPECT_EQ(len, 1UL);
    EXPECT_FALSE(isFatal);
});

mixin TEST!("AssertInternals", "AssertEQ_FailIsFatal", q{
    resetTestState();
    bool caught = false;
    try { ASSERT_EQ(1, 2); }
    catch (FatalFailureException) { caught = true; }
    auto f = currentFailures();
    size_t len = f.length;
    bool isFatal = f[0].fatal;
    resetTestState();  // clear intentional failure before our assertions
    EXPECT_TRUE(caught);
    EXPECT_EQ(len, 1UL);
    EXPECT_TRUE(isFatal);
});

mixin TEST!("AssertInternals", "ExpectTrue_PassAndFail", q{
    resetTestState();
    EXPECT_TRUE(true);
    size_t len0 = currentFailures().length;
    EXPECT_TRUE(false);   // intentional, tests recording
    size_t len1 = currentFailures().length;
    resetTestState();  // clear intentional failure before our assertions
    EXPECT_EQ(len0, 0UL);
    EXPECT_EQ(len1, 1UL);
});

mixin TEST!("AssertInternals", "FloatEQ", q{
    resetTestState();
    EXPECT_FLOAT_EQ(1.0f, 1.0f);
    EXPECT_EQ(currentFailures().length, 0UL);
});

mixin TEST!("AssertInternals", "NearPass", q{
    resetTestState();
    EXPECT_NEAR(3.14, 3.15, 0.02);
    EXPECT_EQ(currentFailures().length, 0UL);
});

mixin TEST!("AssertInternals", "NearFail", q{
    resetTestState();
    EXPECT_NEAR(3.14, 3.15, 0.001);
    size_t len = currentFailures().length;
    resetTestState();  // clear intentional failure before our assertions
    EXPECT_EQ(len, 1UL);
});

mixin TEST!("AssertInternals", "StringChecks", q{
    resetTestState();
    EXPECT_STREQ("abc", "abc");
    EXPECT_STRNE("abc", "xyz");
    EXPECT_STRCASEEQ("ABC", "abc");
    EXPECT_EQ(currentFailures().length, 0UL);
});

mixin TEST!("AssertInternals", "ExceptionChecks", q{
    resetTestState();
    EXPECT_THROW!Exception({ throw new Exception("x"); });
    EXPECT_NO_THROW({ int x = 1; });
    EXPECT_ANY_THROW({ throw new Error("e"); });
    EXPECT_EQ(currentFailures().length, 0UL);
});

// ── Filter / glob ─────────────────────────────────────────────────────────────

mixin TEST!("FilterTest", "GlobStar", q{
    EXPECT_TRUE(matchesFilter("Foo.Bar", "*"));
    EXPECT_TRUE(matchesFilter("Foo.Bar", "Foo.*"));
    EXPECT_TRUE(matchesFilter("Foo.Bar", "*.Bar"));
    EXPECT_FALSE(matchesFilter("Foo.Bar", "Baz.*"));
});

mixin TEST!("FilterTest", "MultiplePatterns", q{
    EXPECT_TRUE(matchesFilter("Foo.Bar", "Baz.*:Foo.*"));
    EXPECT_FALSE(matchesFilter("Qux.Quux", "Foo.*:Bar.*"));
});

// ── Fixture lifecycle ─────────────────────────────────────────────────────────

private int gSetUpCalls;
private int gTearDownCalls;

class LifecycleFixture : TestFixture
{
    override void setUp()    { gSetUpCalls++;    }
    override void tearDown() { gTearDownCalls++; }
}

mixin TEST_F!("LifecycleFixture", "SetUpCalled", q{
    EXPECT_GE(gSetUpCalls, 1);
});

mixin TEST_F!("LifecycleFixture", "TearDownCalledAfterPrevious", q{
    EXPECT_GE(gTearDownCalls, 1);
});
