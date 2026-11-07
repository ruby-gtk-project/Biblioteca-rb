# Component parity — Biblioteca-rb — round 5 (verification pass)

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `828bdd5` |
| Source of the open-gap list | `COMPONENT_PARITY.md` "Still owed after round 4" |
| Audited | 2026-11-07 |

This round does not re-derive the four-axis comparison from zero — round 4
already did that and closed 5 of the remaining open items (Flatpak-refusal
counterpart, the `-1` clamp, the troll gitlink, the GSettings schema compile,
the theme-swatch property-name assertion). This round's job is adversarial
re-verification: run the runtime gate myself, and check that every row
`COMPONENT_PARITY.md` still marks open is still actually open and not quietly
closed-but-unrecorded, or closed-but-still-claimed-open.

## Runtime gate, re-run independently this round

| Command | Result |
|---|---|
| `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb` | **395 of 395 checks passed / DRIVE OK** |
| `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_app.rb` | **31 steps, 2 skipped, 0 failures** |
| `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_sidebar.rb` | **25 steps, 0 failures** |
| `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'` | **38 examples, 0 failures** |
| `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' rake default` | runs all of the above plus RuboCop and `schema:validate` and `gettext:check_pot_drift`; **`Default task complete.`** |

395 + 31 + 25 = **451 checks, 0 failed, across 19 components** — the gate
figure this round's task text cites, reproduced independently rather than
taken on the commit message's word. The 2 skips in `drive_app.rb` are the
same two named in `COMPONENT_PARITY.md` (the tree/search steps, because this
machine has no gi-docgen documentation installed) and are not silently
swallowed — `drive_sidebar.rb` exists specifically to cover that gap with a
synthetic fixture, and does.

One wording risk, not a correctness gap: commit `828bdd5`'s own message says
"394/395 drive checks" for `drive_biblioteca.rb`, which reads as one failing
check. It is not — rerunning it twice this round gives 395/395 both times.
The commit message is ambiguous (it means "395, up from 394") rather than
wrong, but it is exactly the kind of sentence a later reader skims and
mistakes for a known failure, or a reviewer skims and mistakes for a pass
that wasn't checked. Worth a one-line fix in the commit's own record is not
possible after the fact; flagged here so `COMPONENT_PARITY.md`/`PORTING.md`
headers (which currently still say "394 of 394", stale from round 3) get
corrected to 395/395 (or 451 for the combined gate) rather than copied
forward unchanged again.

## Re-verifying each item `COMPONENT_PARITY.md` still lists as owed

| # | Claimed-open item | Re-verified this round | Status |
|---|---|---|---|
| 1 | Upstream bug reports (`FINDINGS.md` #5, #6, #11, #12) not filed | `grep -c` against the issue tracker not attempted (no network tool scope here), but no new filing commit exists on `ruby` since round 4 | still open, correctly recorded |
| 2 | `rake data:install` never run; only the four templates `rake data:validate` checks are observed | `grep -n "data:install" rakelib/biblioteca.rake COMPONENT_PARITY.md` shows the task exists and is cited as unrun; no drive script or spec invokes it | still open, correctly recorded |
| 3 | No pointer/keyboard driving; `Gtk::GestureClick` on the two sidebar rows (`lib/browse_view.rb#click_gesture`, `lib/search_view.rb#click_gesture`) unobserved | `grep -n "pressed\|Gesture" test/drive_*.rb` finds no `gesture.emit`/synthetic-event call in any driver; both click gestures' `pressed` handlers are reached only by name, never fired | still open, correctly recorded |
| 4 | No Flatpak manifest; `flatpak-builder-lint` has nothing to check | `find . -iname '*.flatpak*'` and a `which flatpak-builder-lint` under the dev shell: both empty/absent | still open, correctly recorded |
| 5 | Theme-swatch accessible **label** value unverified over AT-SPI (only the property *name* is asserted, against `Gtk::AccessibleProperty`) | re-ran `test/drive_biblioteca.rb`; it still only asserts the property name, with the same "Can't connect to a11y bus" constraint noted in `FINDINGS.md` | still open, correctly recorded |

All five items `COMPONENT_PARITY.md` lists as still owed after round 4 are,
independently, still owed. None of them is quietly fixed-and-unrecorded, and
none of them is recorded-as-open while actually fixed. The ledger is accurate
as of `828bdd5`.

## New this round: `rake data:validate` fails when run directly, and is deliberately excluded from `rake default`

Running `nix develop --command rake data:validate` directly (not via `rake
default`, which does not call it) exits non-zero:

```
appstreamcli validate --no-net data/app.metainfo.xml
I: org.rubygtkproject.Biblioteca:38: nonstandard-gnome-extension kudos
W: org.rubygtkproject.Biblioteca:57: invalid-iso8601-date 2026-09-xx
✘ Validation failed: warnings: 1, infos: 1, pedantic: 1
```

This is **not a port gap** — `FINDINGS.md` #12 already documents it, with a
`diff` against `origin/main:data/app.metainfo.xml` showing the content is
upstream's unmodified, and explains explicitly that `data:validate` is kept
out of `rake default` *for this reason*, so CI failing for content this port
does not own would be the dishonest outcome, not the honest one. Verified:
`rakelib/default.rake`'s `task default:` list does not include
`"data:validate"`, only `"schema:validate"` — confirmed by reading the task
list, not inferred from the commit message. This is correctly-labelled, not
excused; recorded here as a check performed, not a new gap.

## Verdict

No new component-parity gap found this round. The five items
`COMPONENT_PARITY.md` carries forward from round 4 remain open and are
accurately described. The runtime gate is real (independently reproduced,
not taken on trust) and covers all 19 components by name. Parity is **not**
complete — five named gaps remain — but nothing is mis-stated as closed.
