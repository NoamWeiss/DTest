# dtest

A Google Test-style unit testing framework for the D programming language.

## Features

- `TEST`, `TEST_F`, and `TEST_DISABLED` macros matching Google Test semantics
- `EXPECT_*` (non-fatal) and `ASSERT_*` (fatal) assertion families
- Fixture-based tests with `setUp` / `tearDown` lifecycle hooks
- Filter tests by glob pattern (`--dtest-filter=Suite.*`)
- Shuffle, repeat, and parallel execution
- Per-test timeouts
- JUnit-compatible XML output for CI

## Installation

Add dtest as a dependency in your `dub.json`:

```json
{
    "dependencies": {
        "dtest": "*"
    }
}
```

Then import what you need:

```d
import dtestcore : TEST, TEST_F, TEST_DISABLED;
import assert_;
import fixture : TestFixture;
import runner  : runTests, parseArgs;
```

## Usage

### Plain tests

```d
mixin TEST!("MathSuite", "AdditionWorks", q{
    EXPECT_EQ(1 + 1, 2);
    EXPECT_LT(0, 1);
});
```

### Fixture-based tests

```d
class BankFixture : TestFixture
{
    int balance;
    override void setUp() { balance = 100; }
}

mixin TEST_F!("BankFixture", "Deposit", q{
    fixture.balance += 50;
    EXPECT_EQ(fixture.balance, 150);
});
```

### Disabled tests

```d
mixin TEST_DISABLED!("Suite", "NotReady", "TODO: not implemented yet", q{
    EXPECT_EQ(1, 2); // never runs
});
```

### Main entry point

```d
int main(string[] args)
{
    auto opts    = parseArgs(args);
    auto summary = runTests(opts);
    return summary.failed > 0 ? 1 : 0;
}
```

## Assertions

| Family | Non-fatal (`EXPECT_*`) | Fatal (`ASSERT_*`) |
|--------|------------------------|---------------------|
| Boolean | `EXPECT_TRUE(x)` · `EXPECT_FALSE(x)` | `ASSERT_TRUE(x)` · `ASSERT_FALSE(x)` |
| Equality | `EXPECT_EQ(a, b)` · `EXPECT_NE(a, b)` | `ASSERT_EQ(a, b)` · `ASSERT_NE(a, b)` |
| Ordering | `EXPECT_LT` · `EXPECT_LE` · `EXPECT_GT` · `EXPECT_GE` | `ASSERT_LT` · `ASSERT_LE` · `ASSERT_GT` · `ASSERT_GE` |
| Strings | `EXPECT_STREQ` · `EXPECT_STRNE` · `EXPECT_STRCASEEQ` · `EXPECT_STRCASENE` | `ASSERT_STREQ` · … |
| Floats | `EXPECT_FLOAT_EQ` · `EXPECT_DOUBLE_EQ` · `EXPECT_NEAR(a, b, tol)` | `ASSERT_FLOAT_EQ` · … |
| Exceptions | `EXPECT_THROW!E(dg)` · `EXPECT_NO_THROW(dg)` · `EXPECT_ANY_THROW(dg)` | `ASSERT_THROW!E(dg)` · … |
| Death | `EXPECT_DEATH(dg)` | — |
| Misc | `SUCCEED()` · `EXPECT_FAIL(msg)` | `ASSERT_FAIL(msg)` |

## CLI options

| Flag | Description |
|------|-------------|
| `--dtest-filter=<glob>` | Run only matching tests, e.g. `Suite.*` or `*.Add` |
| `--dtest-repeat=<N>` | Repeat the whole suite N times |
| `--dtest-shuffle` | Randomise test order |
| `--dtest-shuffle-seed=<N>` | Fixed seed for reproducible shuffling |
| `--dtest-jobs=<N>` | Parallel workers (default: 1) |
| `--dtest-timeout-ms=<N>` | Per-test timeout in milliseconds |
| `--dtest-xml[=path]` | Write JUnit XML (default: `dtest_results.xml`) |
| `--dtest-brief` | Only print failures |
| `--dtest-list-tests` | Print test names and exit |

## Building

Requires a D compiler (LDC or DMD) and [DUB](https://dub.pm).

```sh
# Run the self-tests
dub run --compiler=ldc2 --config=selftest

# Build and run the example
dub run --compiler=ldc2 --config=example
```

## License

MIT — see [LICENSE](LICENSE).
