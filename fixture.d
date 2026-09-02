/**
 * DTest fixture — Base class and lifecycle support for TEST_F fixtures.
 *
 * Mirrors GoogleTest's ::testing::Test:
 *   - SetUpTestSuite  / TearDownTestSuite  (called once per suite)
 *   - setUp           / tearDown           (called around each test)
 */
module fixture;

/// Base class for all test fixtures.
class TestFixture
{
    /// Called once before any test in the suite runs.
    static void setUpTestSuite() { }

    /// Called once after all tests in the suite have run.
    static void tearDownTestSuite() { }

    /// Called before each individual test.
    void setUp() { }

    /// Called after each individual test (even if the test failed).
    void tearDown() { }
}

/**
 * Helper called by TEST_F-generated code.
 * Constructs a fresh fixture, runs setUp/body/tearDown, guaranteeing
 * tearDown even when the body throws a FatalFailureException.
 */
void runFixtureTest(F : TestFixture)(void delegate(F) body)
{
    import dtestcore : FatalFailureException;

    auto f = new F();
    f.setUp();
    scope(exit) f.tearDown();

    try
        body(f);
    catch (FatalFailureException)
    { /* already recorded; tearDown still runs via scope(exit) */ }
}
