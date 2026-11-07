# Component parity — round 6

Date: 2026-11-07. Port commit audited: `2844629` (no application-code diff
from round 5's `828bdd5`; `.reports/*-round5.md` and the two "Parity
reports" commits are the only things that changed since, plus `PORTING.md`).

## Runtime gate, independently re-run this round (not taken on the harness's word)

```
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb
  -> 395 of 395 checks passed, DRIVE OK
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_app.rb
  -> 31 steps, 2 skipped, 0 failures
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_sidebar.rb
  -> 25 steps, 0 failures
```

395 + 31 + 25 = **451 checks, 0 failed**, across the same 19 `lib/`
components round 5 named — matches the task's stated gate (`drive_ok=true,
451 passed, 0 failed`) exactly, reproduced fresh rather than copied from the
prior report. The gate's own claim of "16 components" does not match this
repo's component count (19, by every grouping this port's own docs use —
see `.reports/component-identification-round6.md`); this is recorded as a
wording mismatch, not a reason to doubt the 451 figure, which was run live.

The `drive_app.rb` 2 skips are the same as round 5: no `gi-docgen`
documentation tree on this machine, and are covered instead by
`drive_sidebar.rb`'s synthetic fixture (independently confirmed passing
above, not just cited).

## Re-verifying each item the ledger still carries as open

Nothing in `lib/`, `exe/`, `data/`, `po/`, or the rakelib changed since
round 5 (`git diff --stat 828bdd5 HEAD -- lib exe test spec po data
rakelib`, empty), so each of round 5's five open items was re-checked
against the unchanged code rather than re-derived from scratch:

| # | Item | Re-check this round | Status |
|---|---|---|---|
| 1 | Upstream bug reports (`FINDINGS.md` #5, #6, #11, #12) not filed | No filing commit on `ruby` since round 5 | still open |
| 2 | `rake data:install` never run | `grep -n "data:install" rakelib/biblioteca.rake` — task exists, still not called by any driver/spec/CI job (`grep -rn "data:install" .github/workflows/ci.yml rakelib/default.rake` empty) | still open |
| 3 | No pointer/keyboard driving of `Gtk::GestureClick` on `lib/browse_view.rb#click_gesture` / `lib/search_view.rb#click_gesture` | `grep -n "gesture\.emit\|synthetic" test/drive_*.rb` still finds no event-level fire of either gesture; both handlers still reached only by direct method call | still open |
| 4 | No Flatpak manifest; `flatpak-builder-lint` has nothing to check | `find . -iname '*.flatpak*' -not -path './vendor/*'` empty | still open |
| 5 | Theme-swatch accessible **label** value unverified over AT-SPI (name only, via `Gtk::AccessibleProperty`) | Re-ran `test/drive_biblioteca.rb` above; same assertion, same a11y-bus constraint | still open |

All five remain open, unchanged, and are not newly excused or newly
mis-stated as closed anywhere in `COMPONENT_PARITY.md` or `PORTING.md`.

## Staleness carried forward from round 5, still unfixed

Round 5 flagged two ledger-staleness items. Both are still present,
unfixed, as of this commit:

- `COMPONENT_PARITY.md:364` still says "394 of 394" where the live number
  is 395/395 (451 combined). Confirmed by re-grepping the current file.
- `TEST_PARITY.md:11`'s "Test command" cell still says `bundle exec rspec`,
  which still fails (`Gem::Exception: can't find executable rspec for gem
  rspec-core`) on this checkout; the working command is the longer `ruby
  -e 'require "rspec/core"; ...'` the dev-shell banner prints. Confirmed by
  re-running `bundle exec rspec` directly this round: same failure.

Neither is a false green (both describe a real, passing thing with a stale
number or a wrong invocation), but neither has been fixed since round 5
flagged it, so a reader following either ledger verbatim still hits a wrong
number or an exception. Carried forward rather than silently dropped.

## Verdict

No new component-parity gap found. The five gaps and two staleness items
round 5 found are all still present, unchanged, and accurately described.
Parity is **not** complete. `clean: false`.
