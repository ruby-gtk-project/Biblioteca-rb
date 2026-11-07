# Port status — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4ededb8dff1b537de09d25ce2e55d1997c43d3` (`9e4eded`) |
| Port | this branch, `ruby` |
| Reports | `.reports/component-identification.md`, `.reports/component-parity.md`, `.reports/test-parity.md`, `.reports/translation-parity.md`, `.reports/accountability-ensurance.md` |
| Repo ledgers | `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`, `FINDINGS.md` |
| Reports last audited | 2026-11-06, at port commit `ced6a5b` |
| This header regenerated | 2026-11-07, at port commit (this round's, see `git log -1`) |

**This header was stale and has been rewritten.** The previous version said
"Last audit 2026-11-02, at port commit `d63ee49`" and "Nothing in this port
has been run" — both false by the time they were last read: the `.reports/`
files themselves (audited 2026-11-06, four days later, at `ced6a5b`) already
record `394 of 394 drive checks`, `36 examples, 0 failures` and three
independent re-runs. That gap between what this file claimed and what the
dated reports next to it already said is itself an accountability finding
(`.reports/accountability-ensurance.md` F-7) and will not recur if this file
is regenerated from the reports' own headers each time it is touched, which
is what the table above now does — its two dates are different because the
audits and this resume document are not produced by the same pass, and
pretending they are is exactly the error being corrected.

Current, re-verified this round: `nix develop --command xvfb-run -a -s
'-screen 0 1600x1200x24' rake default` runs the full RSpec suite (38
examples), RuboCop, `rake schema:validate`, `rake gettext:check_pot_drift` and
all three UI drivers (31 / 25 / 394 steps) end to end and exits 0. See
`TEST_PARITY.md` for the commands and `.github/workflows/ci.yml` for the CI
job that now runs the same thing on every push.

## Upstream

Biblioteca is a GNOME documentation browser: a sidebar tree of GNOME platform
docs with fuzzy search, and a tab view of WebKit webviews with navigation,
zoom, find-in-page and a URL bar for online pages. It is implemented in
JavaScript (GJS) with blueprint (`.blp`) UI, GTK 4 + libadwaita 1 +
WebKitGTK 6.0. The spec lives on the `origin/main` ref of this repo; read it
with `git show origin/main:<path>`. It is never checked out and never merged.

## Done

Written, in house style, mapped one upstream source file to one `lib/` file,
and run: `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' rake
default` draws every row below in a real GTK process (see "Open gaps" and
TEST_PARITY.md for the exact counts).

| Port | Upstream |
|---|---|
| `lib/biblioteca.rb` | the file map; requires the application |
| `lib/biblioteca/application.rb` | `src/application.js`, `src/actions.js`, `src/main.js` |
| `lib/package.rb` | `src/bin.js` (`imports.package.init`), `src/main.js` |
| `lib/about_dialog.rb` | `src/about.js` |
| `lib/settings.rb` | `data/app.gschema.xml`, `src/util.js` |
| `lib/style.rb` | `src/style.css` (heredoc, copied verbatim) |
| `lib/window.rb` | `src/window.blp` + `src/window.js` |
| `lib/window_state.rb` | `troll/src/util.js` (`persistWindowState`) |
| `lib/shortcuts_window.rb` | `src/Shortcuts.js`; `src/Shortcuts.blp` → `data/ui/shortcuts.ui` |
| `lib/find_overlay.rb` | `src/FindOverlay.blp` + `src/FindOverlay.js` |
| `lib/web_view.rb` | `src/WebView.blp` + `src/WebView.js` |
| `lib/sidebar.rb` | `src/sidebar/Sidebar.blp` + `src/sidebar/Sidebar.js` |
| `lib/sidebar_menu.rb` | `menu menu_app` in `src/sidebar/Sidebar.blp` |
| `lib/theme_selector.rb` | `troll/src/widgets/ThemeSelector.{js,blp,css}` |
| `lib/zoom_buttons.rb` | `src/sidebar/ZoomButtons.blp` + `.js` |
| `lib/browse_view.rb` | `src/sidebar/BrowseView.blp` + `.js` |
| `lib/search_view.rb` | `src/sidebar/SearchView.blp` + `.js` |
| `lib/documentation_page.rb` | `src/sidebar/DocumentationPage.js` |
| `lib/doc_index.rb` | `build-aux/build-index.js` |
| `lib/fzy.rb` | `src/sidebar/fzy.js` |
| `data/app.{desktop,gschema.xml,service,metainfo.xml}`, `data/icons/` | upstream `data/` + `src/icons/`, app id substituted; `diff` empty after normalising the id |
| `po/` (`POTFILES.in`, `extract.rb`, the `.pot`) | the 64 upstream msgids, byte for byte |
| `rakelib/biblioteca.rake` | the install and two validate steps of `data/meson.build` |

The two upstream `.blp` list-item factories were rebuilt as
`Gtk::SignalListItemFactory` with `setup`/`bind` handlers
(`lib/browse_view.rb:144`, `lib/search_view.rb:171`), not transcribed.

## Not started

| Upstream | State |
|---|---|
| `build-aux/app.drey.Biblioteca.json`, `build-aux/app.drey.Biblioteca.Devel.json`, `build-aux/modules/*.json` | no `build-aux/`, no manifest of any kind in the port. Upstream's only supported distribution |
| `data/meson.build:38` — `appstream-util validate` (the stricter Flathub validator) | has a port counterpart as of this round — `rake data:validate` runs it — but it fails on upstream's own content (`FINDINGS.md` #12), not a port defect |
| `Makefile:19-20` — `flatpak-builder-lint` on both manifests | nothing to lint, because of the manifest row above |

`src/bin.js:27-32` (the Flatpak-required startup refusal) and `src/init.js:8`
(dead code upstream, no call site) have moved out of this table: the former
now has a port counterpart (`exe/biblioteca`'s doc-root check, see "Open
gaps" below); the latter stays unported deliberately, since upstream itself
never calls it.

## Open gaps

Regenerated from each `.reports/` file's own header, as of its own audit
(2026-11-06, `ced6a5b`), with what this round (commit after `f938229`) has
since closed marked inline. These five counts are not summed into one
headline figure: they come from different axes (components, tests,
translation, accountability) with different units, and the previous header's
unreconciled "21 vs. 15" was itself the F-7 finding — a sum presented as
authoritative that nobody could actually derive from the cited sources is
worse than five counts kept separate.

* **`.reports/component-parity.md` — 7 open as audited.** Closed this round:
  1 (Flatpak startup refusal — `exe/biblioteca` now refuses to start when no
  documentation root exists), 3 and 4 (`troll` vendored at
  `vendor/troll/`, pinned to `37b53b2`), 6 (`Sidebar#start_index`'s `-1`
  clamp — see `FINDINGS.md` #11 for what actually changed), 7 (GSettings
  schema now compiled unconditionally, not gated on a step nobody ran
  automatically). Partially closed: 5 (the accessible-property *name* is now
  asserted against `Gtk::AccessibleProperty`'s list in
  `test/drive_biblioteca.rb`; the label itself is still not verified over
  AT-SPI). Still open: 2 (Flatpak packaging — no manifest exists; recorded as
  a gap, not reworded as a non-goal). **Open now: 1 full gap, 1 half-gap**,
  down from 7.
* **`.reports/test-parity.md` — 3 of 7 as audited** (`rake data:validate`
  silently validated nothing; `appstreamcli`/`appstream-util`/
  `flatpak-builder-lint` all missing from the devshell). Closed this round:
  `desktop-file-utils`, `appstream` and `appstream-glib` are all in the
  devshell now, `rake data:validate` runs both AppStream validators for real
  (and surfaces upstream content issues — `FINDINGS.md` #12 — rather than
  silently passing), and `rake default` plus a new CI workflow
  (`.github/workflows/ci.yml`) run the suite, RuboCop, `rake
  schema:validate`, `rake gettext:check_pot_drift` and all three drivers on
  every push. Still open: `flatpak-builder-lint` on both manifests — same
  cause as component-parity gap 2. **Open now: 1 of 3** (component-parity
  gap 2 and this one are the same underlying gap, counted once each by their
  own report).
* **`.reports/translation-parity.md` — 2 gaps as audited** (TP-1: no drift
  check on the `.pot`; TP-2: no real catalogue, nothing proving `_()` ever
  returned a translated string). Both closed this round: `rake
  gettext:check_pot_drift` (TP-1) and `po/fr.po`, a complete 64/64-message
  French catalogue proven by `spec/translation_spec.rb` (TP-2). **Open now:
  0 of 2.**
* **`.reports/component-identification.md` — CI-1, 2 units unidentifiable**
  (the `troll` gitlink). Closed this round by the same vendoring that closed
  component-parity gaps 3 and 4. **Open now: 0.**
* **`.reports/accountability-ensurance.md`** does not count in the same
  units as the four above — it names specific sentences and specific files,
  not a gap tally — so it is not folded into this list; read it directly. Its
  F-6 and F-7 findings are both answered this round: F-6 (the Flatpak-refusal
  framing) by rewriting `FINDINGS.md` #10 and `lib/package.rb`'s comment to
  state plainly that the feature was missing, not settled; F-7 (this file's
  own stale header) by the regeneration above.

## Blockers

None of these block the port from running — `webkit-gtk` is installed and
working via the Nix devshell's `nix/Gemfile`, and the drivers above exercise
every row named here. Kept as a record of what still constrains the port's
*behaviour*, not its ability to start:

* **Flatpak-only runtime, upstream side.** `src/bin.js` hard-exits outside
  Flatpak and the default page is `file:///app/share/doc/gtk4/index.html`,
  i.e. the Flatpak SDK docs mounted at `/app`. A checkout-run Ruby port has no
  `/app`, so the default URI and the doc-index root are configurable here
  (`DocIndex::DEFAULT_ROOTS`, `Window#default_uri` → `Sidebar#start_uri`),
  and `exe/biblioteca` now refuses to start on the one condition it can check
  in the sandbox guard's place — see "Open gaps" above and `FINDINGS.md` #10.
* **`doc-index.json` has no source outside Flatpak.** Upstream's
  `build-aux/build-index.js` runs as a meson install script over the installed
  GI-DocGen HTML trees. `lib/doc_index.rb` rebuilds the same structure at
  first run into `XDG_CACHE_HOME/biblioteca-rb/`, but with no GI-DocGen tree
  on the machine `#scan_libraries` returns `[]` and the sidebar would be
  empty — which is exactly the condition `exe/biblioteca`'s new startup
  refusal now catches instead of opening uselessly.
* **No `po/` on `origin/main`** despite ~40 `_()` msgids in the blueprints and
  JS, so there is no catalogue to port. `po/fr.po` (this round) is the port's
  own, not a carried-over upstream one.
* **`Adwaita::Application` is broken in the bindings**, so the application
  object is a `Gtk::Application` with an `Adwaita::ApplicationWindow`; and
  `GtkShortcutsWindow` is deprecated in GTK 4.18 but kept, because the Adwaita
  replacement cannot draw the two gesture rows (`FINDINGS.md` #7).

## Running it

```sh
direnv allow                                              # or: nix develop
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' rake default
nix develop --command xvfb-run -a ruby exe/biblioteca      # just the app
```

The dev shell's own banner (printed on every `nix develop`) names the exact
drive and spec commands for this checkout — read it rather than guessing at
flags. `.claude/skills/ruby-gtk` is the style contract; invoke it before
touching any widget file. `rubocop` (against a resolving gemset) before
committing.
