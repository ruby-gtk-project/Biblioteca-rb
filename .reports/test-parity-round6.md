# Test parity — round 6

Date: 2026-11-07. No test-affecting diff since round 5 (`git diff --stat
828bdd5 HEAD -- spec test rakelib`, empty).

## Upstream has no test suite to port (re-confirmed)

`git ls-tree -r --name-only origin/main | grep -iE 'test|spec'` was re-run
this round: still empty. Upstream (Biblioteca, GJS) ships no automated
tests. "Test parity" for this port is therefore 0/0 upstream tests ported,
met trivially — the port owes itself a safety net it did not inherit, which
`TEST_PARITY.md` already states and this round does not weaken.

## Suite re-run live this round, not taken on the prior report's word

| Suite | Command actually run | Result |
|---|---|---|
| RSpec | `ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` | **38 examples, 0 failures** |
| `test/drive_biblioteca.rb` | `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb` | **395 of 395, DRIVE OK** |
| `test/drive_app.rb` | same | **31 steps, 2 skipped, 0 failures** |
| `test/drive_sidebar.rb` | same | **25 steps, 0 failures** |

`bundle exec rspec` — the command `TEST_PARITY.md:11` actually names — was
also re-run directly this round and still fails:

```
Gem::Exception: can't find executable rspec for gem rspec-core.
rspec-core is not currently included in the bundle, perhaps you meant to
add it to your Gemfile?
```

This is the same finding round 5 made; it is unfixed. `TEST_PARITY.md`
still tells a reader to run a command that raises before any example runs.

## Coverage check: does the suite exercise all 16/19 components the gate claims?

Cross-checked `.reports/drive.md`'s per-component table against the current
`lib/` listing: every file in `lib/*.rb` and `lib/biblioteca/*.rb` appears
in the table, and no table entry is missing from the tree. The drivers'
451 checks plus the 38 RSpec examples are the only executed verification
this port has; nothing claims coverage of a component that was never
exercised. (See `.reports/component-parity-round6.md` for the "16 vs 19"
wording mismatch in the gate description — it does not change what was
actually run or what it covers.)

## Verdict

0/0 upstream tests, met trivially. The port's own suite (38 + 451 = 489
checks) is real, green, and was independently re-executed this round. One
unfixed documentation gap carries forward from round 5: `TEST_PARITY.md`'s
stated test command does not run as written.
