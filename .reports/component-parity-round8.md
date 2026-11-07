# Component parity — round 8

Date: 2026-11-07. Port commit audited: `781d5f1`. Diff since round 7's
`7dfed31`: `COMPONENT_PARITY.md`, `flake.nix`, `rakelib/default.rake`,
`test/drive_middle_click.rb` (new), and six `build-aux/*.json` files (new).
No `lib/`, `spec/`, `po/`, or `data/` diff (confirmed in `.reports/
component-identification-round8.md`).

## Runtime gate, independently re-run this round

```
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb
  -> 395 of 395 checks passed, DRIVE OK
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_app.rb
  -> 31 steps, 2 skipped, 0 failures
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_sidebar.rb
  -> 25 steps, 0 failures
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_middle_click.rb
  -> 5 steps, 0 failures (BrowseView) + 3 steps, 0 failures (SearchView) = 8 steps, 0 failures
```

395 + 31 + 25 = **451 checks, 0 failed** — matches the task's gate exactly
(`drive_ok=true, 395 checks passed, 0 failed`), reproduced live. The new
`drive:middle_click` driver (8 more checks, now wired into `rake drive`)
is additional runtime coverage the task's gate figure predates; combined
total is now **459** driver checks + 38 RSpec examples = 497, all green,
all re-run live this session, not copied from `PORTING.md`.

## Re-verifying round 7's five open items

| # | Item | This round's re-check | Status |
|---|---|---|---|
| 1 | Upstream bug reports (`FINDINGS.md` #5, #6, #11, #12) not filed against upstream | No filing commit on `ruby`. Commit `781d5f1`'s own message states the four reports "were drafted but could not be filed — `gh issue create` against sonnyp/Biblioteca was denied by the sandbox as an external system write." This is a genuine environment constraint, documented honestly, not an excuse dressed as a decision | still open |
| 2 | `rake data:install` never run | Already closed round 7; unchanged | closed (carried) |
| 3 | No pointer/keyboard driving of `Gtk::GestureClick` on the two sidebar rows | **Closed this round.** `test/drive_middle_click.rb` first reproduces the binding gap live (`signal_emit leaves current_button at 0`), then synthesizes a *real* X11 button-2 press via `xdotool`/XTest against the xvfb display for both `BrowseView#on_pressed` and `SearchView#on_pressed`, and asserts `win.new-tab` actually fires with the clicked row's uri (and that a real left click does not). Re-run live this round: 8/8 steps pass. This is the strongest possible closure of this gap — a real pointer event, not a stub | **closed** |
| 4 | No Flatpak manifest; `flatpak-builder-lint` has nothing to check | **Narrowed, not closed.** `build-aux/org.rubygtkproject.Biblioteca.json`, `.Devel.json`, and six `build-aux/modules/*.json` now exist, porting upstream's manifest shape under this port's own app id. But: (a) the `Biblioteca` module only runs `gem build` / `gem install` / `rake data:install` — it does not vendor the six runtime gems (`gtk4`, `adwaita`, `webkit-gtk`, `gettext`, plus transitive deps) as Flatpak sources, so a `flatpak-builder` build from this manifest would fail offline; (b) `flatpak-builder-lint` is confirmed absent from this environment (`which flatpak-builder-lint` and `which flatpak-builder` both fail; not in nixpkgs under this flake), so the manifest has never been linted at all, by anyone, in this environment. The commit message states both limitations itself rather than claiming the gap closed — an honest partial, but still a real gap: a manifest that cannot build and has never been linted is not "done" | **still open** (reclassified: manifest exists, build/lint unverified) |
| 5 | Theme-swatch accessible **label** value unverified over AT-SPI (name only) | Re-ran `drive_biblioteca.rb` above; same `Gtk::AccessibleProperty` name-only assertion, same "Can't connect to a11y bus" environment constraint, unchanged | still open |
| 6 | Stale "394 of 394" in `COMPONENT_PARITY.md` | **Closed this round.** `grep -rn "394 of 394" COMPONENT_PARITY.md` → zero hits in current content (only historical references inside `PORTING.md`'s own narration of the fix, and in prior rounds' `.reports/*.md`, remain — correctly, as history). The live line now reads "395 of 395 checks (451..." | **closed** |
| 7 | `TEST_PARITY.md` test command | Already closed round 7; unchanged | closed (carried) |

## Verdict

Two more items closed for real this round (3 and 6), both independently
reproduced — item 3 with the strongest evidence this audit has seen for
any gap closure (a real synthesized X11 pointer event, not a signal
stub). Item 4 moves from "nothing exists" to "something exists but is
unverified and admits it cannot build offline" — progress, but not a
closed gap, and recorded as such rather than counted as done because a
manifest attempted it. Two items remain genuinely open and unchanged (1,
5), both backed by documented, re-confirmed environment constraints
rather than hand-waving. Parity is **not** complete. `clean: false`.
