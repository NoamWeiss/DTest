# Contributing to DTest

Thanks for your interest. Contributions of all sizes are welcome.

## Before you start

- Open an issue first for anything beyond a small fix, so the approach can
  be agreed before you spend time on it.
- DTest deliberately follows [GoogleTest](https://github.com/google/googletest)
  naming and semantics. New features should have a GoogleTest counterpart
  or a clear reason to diverge.

## Making a change

1. Fork the repository and create a branch from `master`.
2. Make your change. Keep the existing style: four-space indentation,
   aligned imports, and a doc comment on every public symbol.
3. Add or update self-tests in `selftest_cases.d`.
4. Confirm everything passes:

   ```sh
   dub run --compiler=ldc2 --config=selftest
   dub run --compiler=ldc2 --config=example
   ```

5. Open a pull request against `master`. CI must pass before it can merge.

## Licensing

By submitting a contribution you agree that it is licensed under the
project's [BSD 3-Clause License](LICENSE). Do not copy code from
GoogleTest or any other project into DTest.
