# Test parity — round 7

Date: 2026-11-07. No test-affecting diff since round 5
(`git diff --stat 828bdd5 HEAD -- spec test rakelib`, empty).

## Upstream has no test suite to port (re-confirmed)

`git ls-tree -r --name-only origin/main | grep -iE 'test|spec'` re-run this
round: still empty. Upstream (GJS) ships no automated tests; `meson.build`
has no `test()` call and the `Makefile`'s `test` target is `make lint`.
Test parity is 0/0 upstream tests ported, met trivially. This is unchanged
across every round so far and is not in dispute.

## Suite re-run live this round

| Suite | Command actually run | Result |
|---|---|---|
| RSpec | `ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` | **38 examples, 0 failures** |
| `test/drive_biblioteca.rb` | `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb` | **395 of 395, DRIVE OK** |
| `test/drive_app.rb` | same | **31 steps, 2 skipped, 0 failures** |
| `test/drive_sidebar.rb` | same | **25 steps, 0 failures** |

489 total checks (38 + 451), all green, all executed in this session —
not carried forward from round 5 or 6's numbers.

## The stale-command gap is now closed

Round 5 and round 6 both flagged `TEST_PARITY.md:11`'s "Test command" cell
for naming `bundle exec rspec`, which raises before any example runs. As of
commit `7dfed31` the cell now reads the long `ruby -e 'require
"rspec/core"; ...'` form:

```
grep -n "Test command" TEST_PARITY.md
11:| Test command | `ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper", "spec"])'` |
```

That command was run above and passed. As a negative control, `bundle
exec rspec` was also re-run directly this round and still fails with
`Gem::Exception: can't find executable rspec for gem rspec-core` — which is
exactly why the ledger cell needed fixing, and confirms the fix is not
cosmetic: the old text would have sent a reader into the same dead end
round 5 and round 6 hit, and the new text does not.

**Closed**, independently re-verified rather than taken on `PORTING.md`'s
claim of closure.

## Coverage check: does the suite exercise every component the gate claims?

Cross-checked `.reports/drive.md`'s per-component table against the
current `lib/` listing (unchanged since round 6, confirmed in
`.reports/component-identification-round7.md`): every file in `lib/*.rb`
and `lib/biblioteca/*.rb` appears in the table, and no table entry is
missing from the tree. The one caveat carried every round: `drive_app.rb`
skips 2 of its 33 steps for lack of a `gi-docgen` tree on this machine,
and those 2 steps' intent is covered instead by `drive_sidebar.rb`'s
synthetic fixture — re-run and green above, not assumed.

No component in `lib/` is exercised by zero checks. The task's framing —
"a component no check exercises is unverified, not done" — is checked
against the full file list, not against the gate's own "16" figure, which
this repo's own groupings cannot reproduce (see `.reports/component-
identification-round7.md` and `.reports/component-parity-round7.md`).

## Verdict

0/0 upstream tests, met trivially. The port's own suite (489 checks) is
real, green, and independently re-executed this round. The one
documentation gap round 5 and round 6 both carried forward
(`TEST_PARITY.md`'s broken test command) is now genuinely fixed and
verified fixed, not merely claimed.
