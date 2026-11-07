# Component parity — round 7

Date: 2026-11-07. Port commit audited: `7dfed31` (no application-code diff
from round 6's `2844629`; the diff since round 5's `828bdd5` is confined to
`PORTING.md` and `TEST_PARITY.md` — see
`.reports/component-identification-round7.md`).

## Runtime gate, independently re-run this round

```
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb
  -> 395 of 395 checks passed, DRIVE OK
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_app.rb
  -> 31 steps, 2 skipped, 0 failures
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_sidebar.rb
  -> 25 steps, 0 failures
```

395 + 31 + 25 = **451 checks, 0 failed** — matches the task's gate exactly
(`drive_ok=true, 395 checks passed, 0 failed`), reproduced live on this
checkout, not copied from a prior report. The 2 skips in `drive_app.rb` are
unchanged from round 5/6: no `gi-docgen` tree on this machine, covered
instead by `drive_sidebar.rb`'s synthetic fixture (also re-run above, 0
failures).

The gate text's "16 components" does not match this repo's own component
count (19, confirmed again in `.reports/component-identification-
round7.md`). Recorded as a wording mismatch in the harness-supplied gate
description for the third round running — it does not change the 451
figure or what it covers, and the port makes no "16" claim anywhere to
check against.

## Re-verifying each previously-open item against the unchanged code

No `lib/`, `exe/`, `data/`, `po/`, or `rakelib/` diff since round 5
(`git diff --stat 828bdd5 HEAD -- lib exe test spec po data rakelib`,
empty), so items 1, 3, 4, 5 below are re-checked against the same code
round 5/6 checked, not re-derived from scratch. Items 2 and 7 (round 5's
numbering) are re-verified as newly, genuinely closed by commit `7dfed31`.

| # | Item | This round's re-check | Status |
|---|---|---|---|
| 1 | Upstream bug reports (`FINDINGS.md` #5, #6, #11, #12) not filed against upstream | No filing commit on `ruby` since round 6; `FINDINGS.md` still documents all four without an upstream issue link | still open |
| 2 | `rake data:install` never run | Re-ran independently this round against `/tmp/biblioteca-install-verify` (fresh prefix, not reusing round 6's): produced the desktop entry, metainfo, D-Bus service, compiled schema (`gschemas.compiled`), and the full icon tree (`scalable/{actions,apps}`, `symbolic/apps`) under the prefix, with no manual step | **closed** — independently reproduced, not taken on `PORTING.md`'s word |
| 3 | No pointer/keyboard driving of `Gtk::GestureClick` on the two sidebar rows | `grep -n "gesture\.emit\|synthetic" test/drive_*.rb` still finds no event-level fire of either `click_gesture`; `signal_emit` sites in the drivers are for `create-tab` and `activate`, neither the gesture. `current_button`-stays-0 finding from round 6 (`FINDINGS.md`/`PORTING.md`) re-read, not re-derived — the underlying binding limitation is unchanged | still open |
| 4 | No Flatpak manifest; `flatpak-builder-lint` has nothing to check | `find . -iname '*.flatpak*' -not -path './vendor/*' -not -path './.git/*'` — empty | still open |
| 5 | Theme-swatch accessible **label** value unverified over AT-SPI (name only) | Re-ran `drive_biblioteca.rb` above; same `Gtk::AccessibleProperty` name-only assertion, same "Can't connect to a11y bus" environment constraint | still open |
| 6 | Stale "394 of 394" in `COMPONENT_PARITY.md` | `grep -n "394 of 394" COMPONENT_PARITY.md` → line 364, still present. Live number is 395/395 (451 combined), confirmed above | still open, **third round unfixed** |
| 7 | `TEST_PARITY.md`'s "Test command" cell said `bundle exec rspec` | `grep -n "Test command" TEST_PARITY.md` → now reads the long `ruby -e 'require "rspec/core"; ...'` form. Re-ran that exact command: 38 examples, 0 failures. Re-ran `bundle exec rspec` directly as a negative control: still raises `Gem::Exception: can't find executable rspec for gem rspec-core` | **closed**, genuinely — the cell now names a command that actually runs |

## Verdict

Two items closed for real this round (2 and 7, both independently
reproduced rather than taken on `PORTING.md`'s narrative). Five remain
open and unchanged: 1, 3, 4, 5 (the long-standing component-behaviour and
packaging gaps) and 6, which is now entering its **third** consecutive
round unfixed despite being trivial (one line in `COMPONENT_PARITY.md`).
Parity is **not** complete. `clean: false`.
