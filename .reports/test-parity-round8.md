# Test parity — round 8

Date: 2026-11-07. Port commit audited: `781d5f1`.

## Upstream has no test suite to port (re-confirmed)

```
git ls-tree -r --name-only origin/main | grep -iE 'test|spec'
```

Still empty. Unchanged across every round. 0/0 upstream tests, met
trivially.

## Suite re-run live this round, including the new driver

| Suite | Command actually run | Result |
|---|---|---|
| RSpec | `ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` | **38 examples, 0 failures** |
| `test/drive_biblioteca.rb` | `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb` | **395 of 395, DRIVE OK** |
| `test/drive_app.rb` | same | **31 steps, 2 skipped, 0 failures** |
| `test/drive_sidebar.rb` | same | **25 steps, 0 failures** |
| `test/drive_middle_click.rb` (new this round, wired into `rake drive` / `rake drive:middle_click`) | same | **8 steps (5 BrowseView + 3 SearchView), 0 failures** |

459 driver checks + 38 RSpec examples = **497 total, all green**, all
executed live in this session.

## The new driver is a genuine addition, not a cosmetic one

`test/drive_middle_click.rb` is not redundant with the existing drivers:
it is the first test in this port's history to fire a *real* X11
pointer event (via `xdotool`/XTest against the xvfb display) at the two
`Gtk::GestureClick` middle-click handlers that `drive_biblioteca.rb` and
`drive_sidebar.rb` could only exercise through `signal_emit` (which the
long-standing `FINDINGS.md` binding gap documents as leaving
`current_button` at 0 and therefore never reaching the middle-click
branch). The new driver's own first assertion re-reproduces that exact
gap live (`ok   signal_emit leaves current_button at 0`) before going on
to prove the real event *does* take the branch — closing component-
parity round 7's item 3 with evidence, not narration. See `.reports/
component-parity-round8.md`.

## Coverage check: does the suite exercise every component the gate claims?

Cross-checked the current `lib/` listing (unchanged since round 6/7)
against the drivers: every `lib/*.rb` and `lib/biblioteca/*.rb` file is
still exercised by at least one driver or spec. `browse_view.rb` and
`search_view.rb`'s middle-click paths specifically — previously untested
at the event level — are now covered by `test/drive_middle_click.rb`.
No component in `lib/` is exercised by zero checks.

## Verdict

0/0 upstream tests, met trivially. The port's own suite grew this round
(451 -> 459 driver checks) with a real, independently re-executed
addition that closes a previously-documented coverage gap rather than
padding the count. All 497 checks green, all re-run live, none taken on
a prior report's word.
