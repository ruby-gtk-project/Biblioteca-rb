# Test parity — Biblioteca-rb — round 5 (verification pass)

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `828bdd5` |
| Upstream tests | **0** (re-confirmed) |
| Port specs run this round | **38 examples, 0 failures** |
| Combined UI-driver checks run this round | **451, 0 failed** |
| Audited | 2026-11-07 |

## Re-confirming "upstream has no test suite"

Per the `test-parity` skill, 0/0 must be verified, not assumed:

```
git ls-tree -r --name-only origin/main | grep -iE '^test|/test'   # empty
git show origin/main:meson.build | grep -i test                    # no test() target
git show origin/main:Makefile    | grep -i test                    # `test:` target is `make lint`, not a test run
```

All three checks are empty or non-test, matching `TEST_PARITY.md`'s existing
claim. Upstream genuinely ships no automated test of any kind
(`Test.add_func`, `it(...)`, `unittest`, `pytest`, `#[test]`): the census is
still 0, and parity at 0/0 is still met trivially. The port therefore still
inherits no safety net from upstream and owes itself one — `TEST_PARITY.md`
already says this and it is not weakened here.

## What the port's own suite actually proves, re-run independently

| Suite | Command | Result |
|---|---|---|
| RSpec | `ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run([...])'` (the exact command the dev shell banner prints — `bundle exec rspec` fails: `rspec-core` is not registered as a bundler executable in this gemset) | **38 examples, 0 failures** |
| `test/drive_biblioteca.rb` | `xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb` | **395 of 395 checks, DRIVE OK** |
| `test/drive_app.rb` | same, `drive_app.rb` | **31 steps, 2 skipped, 0 failures** |
| `test/drive_sidebar.rb` | same, `drive_sidebar.rb` | **25 steps, 0 failures** |

**Finding — `bundle exec rspec` does not work on this checkout**, only the
longer `ruby -e 'require "rspec/core"; ...'` form the dev shell banner
prints. `bundle exec rspec` raises `Gem::Exception: can't find executable
rspec for gem rspec-core. rspec-core is not currently included in the
bundle, perhaps you meant to add it to your Gemfile?` This is the command a
reader would reach for first (it is what `TEST_PARITY.md`'s own header names
as "Test command"), and it fails. It is not a count/parity gap — the suite
itself passes once invoked the way the banner says — but it is a
documentation gap: `TEST_PARITY.md`'s "Test command" cell should name the
command that actually works, not the one that raises before a single example
runs. Filed here rather than silently worked around, because a reader
following the ledger's own instructions hits a `Gem::Exception`, not a test
report.

## Extra (non-parity) coverage, re-confirmed present and passing

- `spec/fzy_spec.rb` — fzy ranking/scoring, pinned exactly (unchanged this round).
- `spec/translation_spec.rb` — **new since round 4** (TP-2 per `TEST_PARITY.md`/the round-5 commit): proves `po/fr.po` compiles to a real `.mo` and resolves 64/64 messages through it. Re-ran as part of the 38-example RSpec run above; included, passing.
- Three UI drivers, 451 checks combined, covering all 19 `lib/*.rb` components by name (confirmed against `.reports/drive.md`'s per-component table, cross-checked against the current `lib/` listing — no component in that table is missing from the current tree and no file in the current tree is missing from the table).

## Verdict

Test parity is still **0/0, met trivially**, correctly stated as owing the
port its own safety net rather than inheriting one. The port's own suite
(38 RSpec examples + 451 driver checks) is real — independently re-run this
round, not taken on the prior round's word — and green. One documentation
gap found and recorded: the ledger's stated test command does not run as
written; the dev shell's own banner command does.
