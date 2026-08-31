/**
 * Entry point for `dub run --config=example`.
 */
module example_main;

import runner : runTests, parseArgs;

import dtestcore    : TEST, TEST_F, TEST_DISABLED;
import assert_;
import fixture : TestFixture;

mixin TEST!("ArithmeticTest", "AdditionWorks", q{
    EXPECT_EQ(1 + 1, 2);
    EXPECT_LT(0, 1);
    EXPECT_GT(5, 3);
});

mixin TEST!("ArithmeticTest", "FloatNear", q{
    EXPECT_FLOAT_EQ(0.1f + 0.2f, 0.3f);
    EXPECT_NEAR(3.14159, 3.14, 0.01);
});

mixin TEST!("StringTest", "Comparisons", q{
    EXPECT_STREQ("hello", "hello");
    EXPECT_STRNE("hello", "world");
    EXPECT_STRCASEEQ("Hello", "hello");
});

mixin TEST!("ExceptionTest", "ThrowAndNoThrow", q{
    EXPECT_THROW!Exception({ throw new Exception("boom"); });
    EXPECT_NO_THROW({ int x = 1 + 1; });
    EXPECT_ANY_THROW({ throw new Error("any"); });
});

class BankFixture : TestFixture
{
    int balance;
    override void setUp() { balance = 100; }
}

mixin TEST_F!("BankFixture", "Deposit", q{
    fixture.balance += 50;
    EXPECT_EQ(fixture.balance, 150);
});

mixin TEST_F!("BankFixture", "Withdraw", q{
    fixture.balance -= 30;
    EXPECT_EQ(fixture.balance, 70);
});

mixin TEST_DISABLED!("SkipSuite", "NotYetImplemented", "TODO: implement later", q{
    EXPECT_EQ(1, 2); // never runs
});

int main(string[] args)
{
    auto opts    = parseArgs(args);
    auto summary = runTests(opts);
    return summary.failed > 0 ? 1 : 0;
}
