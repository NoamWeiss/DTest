module selftest_main;

import runner : runTests, parseArgs;

int main(string[] args)
{
    auto opts    = parseArgs(args);
    auto summary = runTests(opts);
    return summary.failed > 0 ? 1 : 0;
}
