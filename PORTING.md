# Port status — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4ededb8dff1b537de09d25ce2e55d1997c43d3` (`9e4eded`) |
| Port | this branch, `ruby` |
| Reports | `.reports/component-identification.md`, `.reports/component-parity.md`, `.reports/test-parity.md`, `.reports/translation-parity.md`, `.reports/accountability-ensurance.md` |
| Repo ledgers | `COMPONENT_PARITY.md`, `TEST_PARITY.md`, `TRANSLATION_PARITY.md`, `FINDINGS.md` |
| Last audit | 2026-11-02, at port commit `d63ee49` |
| Audit verdict | clean = **false** |

This is the resume point. It records what exists, what does not, and what the
audits still hold open. Nothing in this port has been run: the `gtk4`,
`adwaita`, `webkit-gtk` and `gettext` gems are not installed in this checkout
(`ruby -e 'require "gtk4"'` → `LoadError`, `bundle exec rspec` → `command not
found: rspec`). Every claim below is a claim about source text.

## Upstream

Biblioteca is a GNOME documentation browser: a sidebar tree of GNOME platform
docs with fuzzy search, and a tab view of WebKit webviews with navigation,
zoom, find-in-page and a URL bar for online pages. It is implemented in
JavaScript (GJS) with blueprint (`.blp`) UI, GTK 4 + libadwaita 1 +
WebKitGTK 6.0. The spec lives on the `origin/main` ref of this repo; read it
with `git show origin/main:<path>`. It is never checked out and never merged.

## Done

Written, in house style, mapped one upstream source file to one `lib/` file.
None of it has been drawn in a GTK process.

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
| `src/bin.js:27-32` — the Flatpak-required startup refusal | absent, and nothing replaces it. A person with no GNOME docs installed gets an empty sidebar and no explanation |
| `src/init.js:8` — promisified `Gtk.UriLauncher.prototype.launch` | absent. Dead code upstream (no call site on `origin/main`), recorded rather than excused |
| `data/meson.build:38` — `appstream-util validate` (the stricter Flathub validator) | no port counterpart |
| `Makefile:19-20` — `flatpak-builder-lint` on both manifests | nothing to lint, because of the manifest row above |

## Open gaps

The fleet audit figure for this round is **21 gaps, clean = false**. The
per-report counts I can read out of `.reports/` sum to 15, so 6 of the 21 are
not attributable to a report header from this checkout — treat 21 as the
authority and the breakdown below as incomplete.

* `.reports/component-parity.md` — **7 open.** 1 the Flatpak startup refusal;
  2 `Gtk.UriLauncher`; 3 Flatpak packaging; 4 theme-selector accessible
  labels (blocked by `FINDINGS.md` #4 — `gtk_accessible_update_property` has
  no usable Ruby form); 5 `troll` `ThemeSelector`; 6 `troll`
  `persistWindowState`; 7 GSettings schema unreachable without
  `rake schema:compile`, where `lib/settings.rb` falls back to a per-process
  JSON file that is not cross-process and is invisible to `gsettings`.
* `.reports/test-parity.md` — **4 gaps**, 3 of 7 upstream checks ported.
  Gaps: `appstreamcli validate` has no separately runnable task (it shares
  `rake data:validate` with `desktop-file-validate`, which aborts first);
  `appstream-util validate` missing; both `flatpak-builder-lint` runs missing.
* `.reports/translation-parity.md` — **0 gaps** in the key set; all 64 msgids
  present.
* `.reports/accountability-ensurance.md` — **4 load-bearing excuses.**
  (1) `lib/package.rb:46-53` writes the deleted Flatpak refusal up as a design
  decision; (2) `TEST_PARITY.md` on this branch still says *0 upstream tests,
  parity met* when there are 7 — the ledger is wrong and must be corrected to
  match `.reports/test-parity.md`; (3) `COMPONENT_PARITY.md` writes `closed`
  on 16 of 17 round-2 rows that nothing has run — the state should read
  `written, unrun` wherever the claim needs a GTK call; (4) `FINDINGS.md` #5
  and #6 describe upstream bugs the port fixes, and neither bug report has
  been filed, so the port is carrying a private fork of upstream behaviour.

Two units cannot be checked against the pinned ref at all: the `troll`
submodule is a gitlink on `origin/main`, so `lib/theme_selector.rb` and
`lib/window_state.rb` have no spec to compare against in this clone.

## Blockers

* **WebKitGTK 6.0 has no ruby-gnome binding.** Every content pane upstream is
  a `WebKit.WebView`; the find controller, context-menu filtering, user
  script/stylesheet injection, back/forward list and zoom level all have no
  Ruby equivalent. `lib/web_view.rb` and `lib/find_overlay.rb` are written
  against a `webkit-gtk` gem that is not installed here, and the sibling
  `webkit-gtk-rb` checkout is the only lead. This is the largest risk in the
  port and the reason nothing has been run.
* **Flatpak-only runtime.** `src/bin.js` hard-exits outside Flatpak and the
  default page is `file:///app/share/doc/gtk4/index.html`, i.e. the Flatpak
  SDK docs mounted at `/app`. A checkout-run Ruby port has no `/app`, so the
  default URI and the doc-index root are configurable here
  (`DocIndex::DEFAULT_ROOTS`, `Window#default_uri` → `Sidebar#start_uri`).
  The divergence is forced; the missing refusal is still a gap.
* **`doc-index.json` has no source outside Flatpak.** Upstream's
  `build-aux/build-index.js` runs as a meson install script over the installed
  GI-DocGen HTML trees. `lib/doc_index.rb` rebuilds the same structure at
  first run into `XDG_CACHE_HOME/biblioteca-rb/`, but with no GI-DocGen tree
  on the machine `#scan_libraries` returns `[]` and the sidebar is empty.
  A bundled index or a path option is still owed.
* **The `troll` submodule is not checked out.** `ThemeSelector` and
  `persistWindowState` were reconstructed from upstream's imports and must be
  verified against https://github.com/sonnyp/troll. Pin and vendor the sha,
  then compare.
* **No `po/` on `origin/main`** despite ~40 `_()` msgids in the blueprints and
  JS, so there is no catalogue to port. Translation parity goes no further
  than keeping the msgids marked, which `po/` does.
* **`Adwaita::Application` is broken in the bindings**, so the application
  object is a `Gtk::Application` with an `Adwaita::ApplicationWindow`; and
  `GtkShortcutsWindow` is deprecated in GTK 4.18 but kept, because the Adwaita
  replacement cannot draw the two gesture rows (`FINDINGS.md` #7).

## Running it

```sh
direnv allow          # or: nix develop
bundle install        # installs gtk4/adwaita/webkit-gtk/gettext — not done here
rake schema:compile   # so Settings uses Gio::Settings, not the JSON fallback
bundle exec ruby -Ilib exe/biblioteca
```

`.claude/skills/ruby-gtk` is the style contract; invoke it before touching any
widget file. `bundle exec rubocop` before committing.
