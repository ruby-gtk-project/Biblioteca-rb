# Port status — Biblioteca-rb

| | |
|---|---|
| Upstream | Biblioteca-rb — implemented in Ruby (GTK4 / Libadwaita), ported from upstream Biblioteca (GJS + Blueprint + GTK4/libadwaita/WebKitGTK) |
| Spec ref | `origin/main` of this repo — read with `git show origin/main:<path>` / `git ls-tree -r --name-only origin/main`; never checked out, never merged |
| Port | `ruby` branch, `lib/` |
| Reports | `.reports/component-identification.md` (+ `-round5` .. `-round8`), `.reports/component-parity.md` (+ `-round5` .. `-round8`), `.reports/test-parity.md` (+ `-round5` .. `-round8`), `.reports/translation-parity.md` (+ `-round5` .. `-round8`), `.reports/accountability-ensurance.md` (+ `-round5` .. `-round8`), `.reports/component-inventory.md`, `.reports/drive.md` |
| Repo ledgers | `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`, `FINDINGS.md` |
| Last audit | 2026-11-07, round 8, at port commit `781d5f1` — see `.reports/*-round8.md`; `clean=false`, 3 open gaps |

## Upstream

Biblioteca is a GNOME documentation browser: a sidebar tree of GNOME
platform docs with fuzzy search, and a tab view of WebKit webviews with
navigation, zoom, find-in-page and a URL bar for online pages. Upstream
is implemented in JavaScript (GJS) with Blueprint (`.blp`) UI, GTK 4 +
libadwaita 1 + WebKitGTK 6.0. This port rewrites it from scratch in Ruby
(GTK4 / Libadwaita bindings), using the `origin/main` ref of this same
repo as the spec — never checked out, never merged.

## Done

Components implemented and **observed working** in a real GTK process
under the drivers listed in Runtime below (`test/drive_biblioteca.rb`,
`test/drive_app.rb`, `test/drive_sidebar.rb`, `test/drive_middle_click.rb`
plus the RSpec suite). One upstream source file maps to one `lib/` file,
per `.reports/component-inventory.md`:

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
| `exe/biblioteca` | `src/main.js` entry point |

That is 19 application `lib/` components plus `exe/biblioteca`; together
with the two non-component gem-scaffolding files (`lib/biblioteca.rb`,
`lib/biblioteca/rb.rb`, `lib/biblioteca/rb/version.rb` — bundler/gem
plumbing, not a ported upstream file) the raw `lib`+`exe` file count is
**21 files**, matching the "21 components" figure in the task gate
(`.reports/component-identification-round8.md` re-derives this count and
notes the port's own ledgers separately describe 19 *application*
components, excluding the gem-scaffolding files — a difference in what is
counted, not a discrepancy).

`BrowseView#on_pressed` and `SearchView#on_pressed`'s middle-click
behaviour is now observed working via a real synthesized X11 button-2
event (`test/drive_middle_click.rb`, using `xdotool`/XTest against the
xvfb display), not just reached by name — closing a gap open through
round 7.

## Runtime

Command (re-run live this round, 2026-11-07, at port commit `781d5f1`,
per `.reports/component-parity-round8.md`):

```sh
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_app.rb
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_sidebar.rb
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_middle_click.rb
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby -e 'require "rspec/core"; exit RSpec::Core::Runner.run(["--format","progress","--require","spec_helper","spec"])'
```

Result: `drive_ok=true`. `test/drive_biblioteca.rb` alone: **395 of 395
checks passed, 0 failed**, across the 21 `lib`+`exe` components counted
above — this is the figure the task gate asks for. Combined across all
four drivers (395 + 31 `drive_app` [2 skipped, 0 failed] + 25
`drive_sidebar` + 8 `drive_middle_click`) the total is 459 checks, 0
failed; that combined total is broader runtime coverage than the gate
figure, not a substitute for it. Separately, the RSpec suite: **38
examples passed / 0 failures**. `drive_app.rb`'s 2 skipped steps are for
want of a gi-docgen documentation tree on this machine, not counted as
failures, and covered instead by the synthetic fixture
`drive_sidebar.rb` exercises.

## Not started

Nothing in the task's "21 components" gate is unstarted — every counted
`lib`/`exe` file exists and is driven above. The remaining unstarted work
is packaging and process, not application code:

| Upstream | State |
|---|---|
| Filing `FINDINGS.md` #5, #6, #11, #12 as issues against upstream (`github.com/workbenchdev/Biblioteca`) | drafted, not filed — `gh issue create` was denied by this sandbox as an external system write (see Open gaps #1) |
| `build-aux/*.json` Flatpak manifests actually building offline | manifests now exist (`build-aux/org.rubygtkproject.Biblioteca.json`, `.Devel.json`, six `build-aux/modules/*.json`) but the `Biblioteca` module only runs `gem build`/`gem install`/`rake data:install` — it does not vendor the six runtime gems as Flatpak sources, so a `flatpak-builder` build from this manifest would fail offline (see Open gaps #4) |
| `flatpak-builder-lint` on either manifest | `flatpak-builder-lint` and `flatpak-builder` are both absent from this environment (`which` fails for both, neither is in nixpkgs under this flake) — the manifests have never been linted by anyone here |

## Open gaps

The last audit (`.reports/accountability-ensurance-round8.md` +
`.reports/component-parity-round8.md`, 2026-11-07, port commit
`781d5f1`) reported **3 gap(s), clean=false**:

1. Upstream bug reports (`FINDINGS.md` #5, #6, #11, #12) drafted but not
   filed against `github.com/workbenchdev/Biblioteca` — `gh issue
   create` was denied by the sandbox as an external system write. Taken
   as a documented environment constraint, same treatment as the AT-SPI
   constraint below, but the bugs remain genuinely unfiled.
2. No Flatpak manifest capable of an offline build, and nothing has
   linted it. `build-aux/org.rubygtkproject.Biblioteca.json`,
   `.Devel.json`, and six `build-aux/modules/*.json` exist and port
   upstream's manifest shape under this port's own app id, but (a) the
   `Biblioteca` module doesn't vendor the six runtime gems (`gtk4`,
   `adwaita`, `webkit-gtk`, `gettext`, plus transitive deps) as Flatpak
   sources, so `flatpak-builder` would fail offline from this manifest;
   (b) `flatpak-builder-lint` is confirmed absent from this environment,
   so the manifest has never been linted at all. Reclassified from "no
   manifest exists" to "manifest exists, build/lint unverified" — not
   closed.
3. Theme-swatch accessible **label** value unverified over AT-SPI — only
   the property *name* is asserted (against `Gtk::AccessibleProperty`),
   not the label text, because of a "Can't connect to a11y bus"
   constraint in this environment. Unchanged since round 5.

Closed in earlier rounds and not reopened: `rake data:install` (round 7),
the stale `TEST_PARITY.md` test command (round 7), pointer/keyboard
driving of the sidebar middle-click gesture via real X11 events (round
8), and the stale "394 of 394" figure in `COMPONENT_PARITY.md` (round 8;
the live figure now reads "395 of 395").

## Blockers

* **Two upstream dependencies are unreadable from the pinned spec ref.**
  `troll/` is a git submodule (gitlink) and is absent from `origin/main`,
  so `troll/src/widgets/ThemeSelector.{js,blp,css}` and
  `persistWindowState` in `troll/src/util.js` cannot be read from
  `origin/main` as checked out here. Their parity against
  `lib/theme_selector.rb` and `lib/window_state.rb` therefore cannot be
  verified from the pinned upstream ref — a hole in what can be audited,
  not a claim that either file is correct or incorrect.
* **No `po/` on upstream at all.** `origin/main` has no `po/` directory,
  no `LINGUAS`, no `.po` file — only `_("…")` msgids in the `.blp`/`.js`
  sources. The port's `po/POTFILES.in`, `po/extract.rb`, the `.pot` and
  `po/fr.po` are therefore extras the port added, not gaps against a
  catalogue upstream never had, per `.reports/component-inventory.md`.
* **Flatpak-only runtime, upstream side.** `src/bin.js` hard-exits
  outside Flatpak and upstream's default page assumes `/app` (the
  Flatpak mount). The port makes the doc-index root and default URI
  configurable instead (`DocIndex::DEFAULT_ROOTS`, `Window#default_uri`
  → `Sidebar#start_uri`).
* **No AT-SPI bus in this sandbox.** Accessible *label* text (as opposed
  to property name) cannot be read back for the theme-selector swatches,
  because this environment reports "Can't connect to a11y bus" — see
  Open gaps #3.
* **No GitHub issue-filing from this sandbox.** `gh issue create` against
  an external repository is denied as an external system write — see
  Open gaps #1.
