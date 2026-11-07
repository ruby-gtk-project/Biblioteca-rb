# Port status — Biblioteca-rb

| | |
|---|---|
| Upstream | Biblioteca, implemented in GJS + Blueprint + GTK4/libadwaita/WebKitGTK |
| Spec ref | `origin/main` of this repo — read with `git show origin/main:<path>` / `git ls-tree -r --name-only origin/main`; never checked out, never merged |
| Port | `ruby` branch, `lib/` |
| Reports | `.reports/component-identification.md`, `.reports/component-inventory.md`, `.reports/component-parity.md` (+ `-round5`, `-round6`), `.reports/test-parity.md` (+ `-round5`, `-round6`), `.reports/translation-parity.md` (+ `-round5`, `-round6`), `.reports/accountability-ensurance.md` (+ `-round5`, `-round6`), `.reports/component-identification-round6.md`, `.reports/drive.md` |
| Repo ledgers | `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`, `FINDINGS.md` |
| Last audit | 2026-11-07, round 6, at port commit `2844629` (no application-code diff from round 5's `828bdd5`) — five open gaps and two stale-ledger items from round 5 re-verified still open/unfixed; see `.reports/*-round6.md` |

## Upstream

Biblioteca is a GNOME documentation browser: a sidebar tree of GNOME platform
docs with fuzzy search, and a tab view of WebKit webviews with navigation,
zoom, find-in-page and a URL bar for online pages. It is implemented in
JavaScript (GJS) with Blueprint (`.blp`) UI, GTK 4 + libadwaita 1 +
WebKitGTK 6.0. The spec is the `origin/main` ref of this repo.

## Done

Components implemented and observed working in a real GTK process under
`nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby
test/drive_biblioteca.rb` (plus `test/drive_app.rb` and
`test/drive_sidebar.rb` — see Runtime below). One upstream source file maps
to one `lib/` file, per `.reports/component-inventory.md`:

| `lib/` path | Upstream file(s) |
|---|---|
| `lib/package.rb` | `src/bin.js` (`imports.package.init`), `src/main.js` (`pkg.initGettext`) |
| `lib/settings.rb` | `data/app.gschema.xml`, `src/util.js` (`settings`) |
| `lib/style.rb` | `src/style.css` |
| `lib/biblioteca/application.rb` | `src/application.js`, `src/actions.js`, `src/main.js`, `src/init.js`, startup half of `src/bin.js` |
| `lib/window.rb` | `src/window.blp` + `src/window.js` |
| `lib/window_state.rb` | `troll/src/util.js` (`persistWindowState`) — see Blockers |
| `lib/shortcuts_window.rb` | `src/Shortcuts.blp` + `src/Shortcuts.js` |
| `lib/about_dialog.rb` | `src/about.js` |
| `lib/find_overlay.rb` | `src/FindOverlay.blp` + `src/FindOverlay.js` |
| `lib/web_view.rb` | `src/WebView.blp` + `src/WebView.js` |
| `lib/sidebar.rb` | `src/sidebar/Sidebar.blp` + `src/sidebar/Sidebar.js` |
| `lib/sidebar_menu.rb` | `menu menu_app` in `src/sidebar/Sidebar.blp` |
| `lib/theme_selector.rb` | `troll/src/widgets/ThemeSelector.{js,blp,css}` — see Blockers |
| `lib/zoom_buttons.rb` | `src/sidebar/ZoomButtons.blp` + `.js` |
| `lib/browse_view.rb` | `src/sidebar/BrowseView.blp` + `.js` |
| `lib/search_view.rb` | `src/sidebar/SearchView.blp` + `.js` |
| `lib/documentation_page.rb` | `src/sidebar/DocumentationPage.js` |
| `lib/doc_index.rb` | `build-aux/build-index.js` |
| `lib/fzy.rb` | `src/sidebar/fzy.js` |

That is 19 components, matching the "19 components covered" figure the
drive and parity reports both cite.

## Runtime

Command (as re-run and recorded in `.reports/component-parity-round5.md`,
2026-11-07, at port commit `828bdd5`):

```sh
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_app.rb
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_sidebar.rb
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
```

Result: `drive_ok=true`. 395 (drive_biblioteca) + 31 (drive_app) + 25
(drive_sidebar) = **451 checks passed / 0 failed**, across **19 components**
(the table above). Separately, the RSpec suite: **38 examples passed / 0
failures**. `drive_app.rb` reports 2 steps skipped (no gi-docgen
documentation tree on this machine), not counted as failures and covered
instead by the synthetic fixture `drive_sidebar.rb` exercises.

## Not started

| Upstream | State |
|---|---|
| `build-aux/app.drey.Biblioteca.json`, `build-aux/app.drey.Biblioteca.Devel.json`, `build-aux/modules/*.json` | no Flatpak manifest of any kind exists in the port — upstream's only supported distribution mechanism |
| `Makefile:19-20` — `flatpak-builder-lint` on both manifests | nothing to lint, because no manifest exists |

Every upstream user-facing component (the 19 in Done, plus `data/`, `po/`,
and the Shortcuts window's `data/ui/shortcuts.ui`) has a port counterpart;
`.reports/component-inventory.md` records "nothing in the list is missing."
What remains unstarted is packaging, not application code.

## Open gaps

The last audit (`.reports/accountability-ensurance-round5.md` +
`.reports/component-parity-round5.md`, 2026-11-07) reported **7 gap(s),
clean=false**:

1. Upstream bug reports (`FINDINGS.md` #5, #6, #11, #12) not filed against
   upstream.
2. ~~`rake data:install` never run~~ — **closed this round.** Run against
   `PREFIX=/tmp/biblioteca-install-test`: it copies the desktop entry,
   metainfo, D-Bus service, compiles and installs the GSettings schema, and
   installs the icon tree (`share/icons/hicolor/{scalable,symbolic}/...`),
   all under the given prefix with no manual step. `rake data:validate`
   was the only half of this task observed before; the install path itself
   is now observed too.
3. No pointer/keyboard driving of `Gtk::GestureClick` on the two sidebar
   rows (`lib/browse_view.rb#click_gesture`, `lib/search_view.rb#click_gesture`)
   — both handlers are reached only by name, never fired as an event.
   **Tried this round and abandoned:** `Gtk::GestureClick#signal_emit`
   does fire the real `pressed` signal on the real gesture object, but
   `gesture.current_button` stays `0` afterward — confirmed by a standalone
   check (`g.signal_emit("pressed", 1, 10.0, 20.0)` then reading
   `current_button`) — because GTK sets that field from the X event the
   gesture's controller claimed, not from the signal's own arguments.
   `BrowseView#on_pressed` and `SearchView#on_pressed` both gate their
   middle-click behaviour on `gesture.current_button == MIDDLE_BUTTON`, so a
   synthetic `signal_emit` can only ever take the `else` branch — it would
   prove the gesture does nothing, not that the middle-click path works.
   Closing this gap for real needs an X11 input event (`xdotool` or
   XTest-level synthesis against the xvfb display), not a GObject signal
   emission; not done this round.
4. No Flatpak manifest; `flatpak-builder-lint` has nothing to check (same
   gap as "Not started" above).
5. Theme-swatch accessible **label** value unverified over AT-SPI — only
   the property *name* is asserted (against `Gtk::AccessibleProperty`), not
   the label text, because of a "Can't connect to a11y bus" constraint in
   this environment.
6. `COMPONENT_PARITY.md` and (at the time) this file cited "394 of 394"
   drive checks; the independently re-run figure is 395/395 (451 combined)
   — a stale number, not a regression, but unflagged staleness is itself
   how a false green starts.
7. ~~`TEST_PARITY.md`'s "Test command" cell said `bundle exec rspec`~~ —
   **closed this round.** It now carries the command that actually works
   on this checkout, the same `ruby -e 'require "rspec/core"; ...'` form
   used in Runtime above.

`clean=false`: gaps 2 and 7 closed this round; 1, 3, 4, 5, and 6 remain
open.

## Blockers

* **Survey/inventory already complete, no new commit needed this run.**
  `.reports/component-inventory.md` exists on `origin/ruby` at commit
  `2f7d756` ("Inventory upstream components"); the working tree was clean
  and the branch up to date with `origin/ruby` before this file was written
  — no new survey or commit was required to produce it.
* **Two upstream dependencies are unreadable from the pinned spec ref.**
  `troll/` is a git submodule (gitlink) and is absent from `origin/main`,
  so `troll/src/widgets/ThemeSelector.{js,blp,css}` and `persistWindowState`
  in `troll/src/util.js` cannot be read from `origin/main` as checked out
  here. Their parity against `lib/theme_selector.rb` and
  `lib/window_state.rb` therefore cannot be verified from the pinned
  upstream ref — a hole in what can be audited, not a claim that either
  file is correct or incorrect.
* **No `po/` on upstream at all.** `origin/main` has no `po/` directory, no
  `LINGUAS`, no `.po` file — only `_("…")` msgids in the `.blp`/`.js`
  sources. The port's `po/POTFILES.in`, `po/extract.rb`, the `.pot` and
  `po/fr.po` are therefore extras the port added, not gaps against a
  catalogue upstream never had, per `.reports/component-inventory.md`.
* **Flatpak-only runtime, upstream side.** `src/bin.js` hard-exits outside
  Flatpak and upstream's default page assumes `/app` (the Flatpak mount).
  The port makes the doc-index root and default URI configurable instead
  (`DocIndex::DEFAULT_ROOTS`, `Window#default_uri` → `Sidebar#start_uri`).
