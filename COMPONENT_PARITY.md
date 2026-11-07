# Component parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` |
| Source of the gap list | `.reports/component-parity.md` (audited at `7211c78`) |
| Identification | `.reports/component-identification.md` |

This is the port's own ledger, appended to as units land. `.reports/` is an
audit of the port; this file is what the port owes and what it has paid.

**Verification status, stated once and applying to every row below.** The port
now runs. `nix/Gemfile` carries the four runtime gems the code actually
requires — `gtk4`, `adwaita`, `webkit-gtk` and `gettext`, pinned to the 4.3.9
release train — so `nix develop --command xvfb-run -a ruby exe/biblioteca`
opens the window, and two driver scripts walk it:

* `test/drive_app.rb` boots `Biblioteca::Application` as `exe/biblioteca` does
  and activates all 16 `win.*` actions, `app.about`, `app.shortcuts` and both
  `app.color-scheme` targets, opening the main menu — and with it the theme
  selector and the zoom row — in between. 28 steps.
* `test/drive_sidebar.rb` writes a gi-docgen fixture root, reads it through the
  real `DocIndex` and drives a real `Sidebar` in a real window: the tree's
  nesting and ordering, expansion and `collapse_all_rows`, fuzzy search, the
  `kind:` prefix and all three sidebar stack pages. 24 steps.

Both exit 0 on this checkout. What that does **not** cover: the tree and search
steps in `test/drive_app.rb` skip on a machine with no gi-docgen documentation
installed (this one has none, which is why `test/drive_sidebar.rb` supplies its
own); nothing drives a pointer or a keyboard, so the gesture and middle-click
paths are reached only through the actions they end in; and the rows below that
name a specific unverified call still name it, because activating an action is
not the same as checking what it drew.

---

## Round 2 — the 17 gaps `.reports/component-parity.md` raised

| # | Gap | State |
|---|---|---|
| 1 | the whole `data/` tree missing | closed |
| 2 | 7 bundled symbolic icons missing | closed |
| 3 | 5 application icons missing; app id / icon name diverged | closed |
| 4 | header bar never shows "Documentation" | closed |
| 5 | default new-tab URI is a Flatpak-only path | closed |
| 6 | GSettings schema not shipped; settings reimplemented over JSON | closed |
| 7 | shortcuts dialog hid 3 accelerators | closed |
| 8 | the two gesture rows lost their gesture | closed |
| 9 | dialog not modal; two-level grouping flattened | closed |
| 10 | zoom percentage goes stale | closed |
| 11 | `ThemeSelector` was invented, not ported | closed, with one new gap (row 11a) |
| 11a | theme-selector buttons have no accessible label | closed |
| 12 | `WindowState` was guessed, not ported | closed |
| 13 | the `devel` CSS class can never be applied | closed |
| 14 | `GLib.set_application_name` never called | closed |
| 15 | 4 pieces of application setup absent | closed (1 added, 3 recorded) |
| 16 | per-tab handlers never disconnected | closed |
| 17 | the `view.equal?(webview)` divergence undocumented | closed; the upstream report is still owed |

### 1 — `data/`

`data/app.desktop`, `data/app.service`, `data/app.metainfo.xml`,
`data/app.gschema.xml` and `data/screenshot.png` are upstream's files with
`@app_id@` substituted to `org.rubygtkproject.Biblioteca` (and the schema path
to `/org/rubygtkproject/Biblioteca/`). `data/app.service` keeps `@bindir@`,
which `rake data:service` substitutes, as upstream's `configure_file` does.
`rakelib/biblioteca.rake` stands in for `data/meson.build`: `rake data:install`
installs the five, `rake data:validate` runs `desktop-file-validate` and
`appstreamcli` when they are present, `rake schema:compile` compiles a schema
for an uninstalled checkout. The gemspec already globs `data/**/*` into
`spec.files`.

Unverified at runtime: the install tasks have not been run; no
`desktop-file-validate` or `appstreamcli` output has been seen.

### 2, 3 — icons

The seven icons upstream imports out of `src/icons/` are at
`data/icons/hicolor/scalable/actions/`: `edit-find-symbolic`,
`loupe-large-symbolic`, `sidebar-show-symbolic`, `tab-new-symbolic`,
`view-grid-symbolic`, `zoom-in-symbolic`, `zoom-out-symbolic`. The five
application icons are at `data/icons/hicolor/{scalable,symbolic}/apps/` and
`data/icons/`, renamed from `app.drey.Biblioteca*` to
`org.rubygtkproject.Biblioteca*`.

`Biblioteca::Application#register_icons` adds `Package.icon_dir` to the
display's `Gtk::IconTheme` search path on `startup`, which is what makes
`icon-name: "tab-new-symbolic"` resolve. `AboutDialog` now asks for
`Package.icon_name` rather than `@app.application_id`, so a Devel run shows the
Devel icon and a release run the release one.

Unverified at runtime: `Gtk::IconTheme.get_for_display(…).add_search_path` has
not been called; whether the system `hicolor` `index.theme` lists
`symbolic/apps` decides whether the `-symbolic` application icon resolves, and
that is upstream's layout, not a choice of this port's.

### 4 — the header title

`src/window.blp:30` starts `content_page` at `_("Documentation")` and
`src/window.blp:58` binds `header_bar_title.title` to `content_page.title`.
`Window::DOCUMENTATION_TITLE` carries the msgid, `#content_page` is built with
it, `#window_title` is built from `content_page.title`, and
`#connect_signals` connects `content_page`'s `notify::title` to the window
title so the two stay in step. `#on_title_changed` writes `content_page.title`
and no longer writes the header directly.

### 5 — the default URI

`Window#default_uri` is `Sidebar#start_uri` — the uri of the `Gtk-4.0` node in
the index the sidebar has already built — falling back to
`file://#{DocIndex::DEFAULT_ROOTS.first}/gtk4/index.html`. The New Tab button's
action target, the first tab and the `<Control>T` accelerator all read it:
`ShortcutsWindow` takes `default_uri:` and builds its accelerator map from it,
so there is no second copy of the path anywhere.

### 6 — settings

`data/app.gschema.xml` is shipped and installable. `Settings` opens a
`Gio::Settings` whenever the compiled schema can be found — the system default
source first, then `data/schemas` for a checkout that has run
`rake schema:compile` — and `#on_changed`, `#bind` and `#color_scheme_action`
are `signal_connect("changed::…")`, `Gio::Settings#bind` and
`Gio::Settings#create_action` in that case. The JSON file remains only as a
fallback for a checkout with no compiled schema anywhere, is documented in the
class comment as strictly worse, and `#using_gsettings?` / `#location` say
which backend is live.

Nothing migrates JSON values into GSettings. That is a one-way door the port
does not open and does not claim to.

Unverified at runtime: `Gio::SettingsSchemaSource.new(dir, parent, true)`,
`#lookup`, `Gio::Settings.new(schema:, path:)`, `#create_action` and `#bind`
are all taken from `gio2` 4.3.9's own `test/test-settings.rb` and GIR, not from
a run.

### 7, 8, 9 — the shortcuts dialog

`data/ui/shortcuts.ui` is `src/Shortcuts.blp` translated element for element
and loaded with `Gtk::Builder`. It is a `GtkShortcutsWindow`, as upstream's is,
so `modal: true` and `hide-on-close: true` are back, the
section → group → shortcut hierarchy is back (one section, four groups), the
two `shortcut-type: gesture_two_finger_swipe_*` rows are back, and all 26
accelerator strings are upstream's bytes — including
`"<Control>Page_Down <Control>Tab"`, `"<Control>Page_Up <Control><Shift>Tab"`
and `"<Alt>1...0"`, which `GtkShortcutLabel` renders as alternatives and as a
range. The invented strings are gone: no `'Two-finger swipe right'`, no
`'Two-finger swipe left'`, and no dialog title of the port's own —
`GtkShortcutsWindow` supplies "Keyboard Shortcuts" itself.

Why not `AdwShortcutsDialog`, and what it would have cost: `FINDINGS.md` #7.

Unverified at runtime: that `Gtk::Builder` can instantiate the deprecated
`GtkShortcutsWindow` from GTK 4.22's library. The class is in
`Gtk-4.0.gir` 4.22.4 and the builder path needs no Ruby constructor, but no
dialog has been opened.

### 10 — zoom

`Window#connect_webview` connects `notify::zoom-level` on every web view and
`#on_zoom_changed` feeds `sidebar.zoom_buttons.zoom_level` from it, guarded on
the view being the selected one. `#apply_zoom` now only sets the property, so a
zoom WebKit makes by itself — ctrl+scroll, pinch — moves the label.
`#update_webview` calls `#on_zoom_changed` on a tab switch, which is the
`SYNC_CREATE` half of upstream's binding.

### 11 — `ThemeSelector`

Rebuilt from troll's actual source, fetched from
<https://github.com/sonnyp/troll> (the submodule is not checked out here; the
three files were read over HTTP from `raw.githubusercontent.com`). What came
back and what is now in `lib/theme_selector.rb`:

* `ThemeSelector.blp`: `Adw.Bin` → `Box` (horizontal, spacing 12, hexpand) with
  three `CheckButton`s carrying `["theme-selector", "follow"|"light"|"dark"]`,
  `hexpand`, `halign: center`, `focus-on-click: false`,
  `action-name: "app.color-scheme"` and targets `0`, `1`, `4`.
* the real labels: `Follow system style`, `Light style`, `Dark style` — not the
  `Follow System Style` / `Light Style` / `Dark Style` the port had invented.
* `ThemeSelector.js`: the follow button is visible only while
  `system_supports_color_schemes?`, and the root carries the `dark` class while
  `dark?`; both follow their `notify::` signals.
* `ThemeSelector.css`: all 52 lines, as `ThemeSelector::CSS`, loaded once per
  process into its own provider at `PRIORITY_APPLICATION` — which is how troll
  loads it.

Unverified at runtime: `Adwaita::StyleManager#system_supports_color_schemes?`
and `#dark?` are the predicate spellings ruby-gnome generates for
`adw_style_manager_get_*`; neither has been called.

#### 11a — the accessible labels

`ThemeSelector.blp` gives each button an `accessibility { label: … }` block as
well as a tooltip, and for a while this port set the tooltip only. Both are set
now: `ThemeSelector::BUTTON_UI` is a two-line GtkBuilder document carrying the
`<accessibility>` block, `#labelled_button` instantiates each check button from
it with the gettext-translated label interpolated in (XML-escaped), and
`#button` sets the style classes, the tooltip, the action name and the int32
action target on the instance afterwards. No `gtk_accessible_update_property`
is involved, which is what made it impossible before; cause and reproduction in
`FINDINGS.md` #4.

### 12 — `WindowState`

Rebuilt from `persistWindowState` in troll's `src/util.js`. `window-maximized`
and `window-fullscreened` are two-way `Settings#bind`s, and the size is written
from `notify::default-width` / `notify::default-height` through troll's 300 ms
debounce, so a crash or a `SIGTERM` loses at most the last 300 ms of resizing
instead of the whole session. The old single `close-request` handler is gone.
troll's `if (width && height)` guard is kept, with `src/window.blp:6-7`'s
1080×768 as the first-run size.

### 13, 14, 15 — application setup

`Package.set_application_name` is `GLib.application_name = "Biblioteca"`
(`src/bin.js:18`). `Package.init_gettext` is `pkg.initGettext()`
(`src/main.js:4`) and binds both libintl's domain and the Ruby gem's.
`Application#devel?` is `pkg.name.endsWith(".Devel")` (`src/bin.js:24`) and is
passed to `Window.new(devel:)`, so the striped development header can appear;
`BIBLIOTECA_DEVEL` in the environment selects the Devel id, which is what
`-Dprofile=development` does upstream.

Three pieces are deliberately absent and are recorded at the top of
`lib/package.rb`, each with what replaces it: the Flatpak guard
(`src/bin.js:27-32`), `resource_base_path` (`src/application.js:11`) and the
`LANG=en_US.UTF-8` launcher wrapper (`src/biblioteca`).

### 16 — handler lifetimes

`Window#connect_webview` records the five handler ids it connects per tab in
`@handlers[page]`, and `#release_tab` — the `page-detached` handler —
disconnects them alongside the `@overlays` delete.

### 17 — the divergence

`lib/window.rb`'s class comment names it and points at `FINDINGS.md` #5, which
describes upstream's bug, how to see it, and what the port does instead.
**Still owed:** the issue has not been filed against
<https://github.com/workbenchdev/Biblioteca/issues>.

---

## Round 4

1. **The Flatpak-required startup refusal (`src/bin.js:27-32`).** `lib/package.rb`'s
   class comment used to say only that this port replicates no such guard.
   `exe/biblioteca` now refuses to start — `warn` plus `exit(1)`, upstream's
   shape — when `DocIndex.default_root` finds no GTK/GNOME API documentation
   anywhere `DocIndex::DEFAULT_ROOTS` looks, which is the one condition this
   port can check in the sandbox check's place and the one that leaves the
   app just as useless as a missing sandbox would upstream (a permanently
   empty sidebar, no explanation). `lib/package.rb`'s comment and
   `FINDINGS.md` #10 are both rewritten to say so plainly rather than call it
   a settled design decision. Verified: `exe/biblioteca` exits 1 with the
   message on this checkout (no GNOME docs installed), and
   `test/drive_biblioteca.rb` still passes 394/394 because it drives
   `Biblioteca::Application` directly against a fixture, the same way
   upstream's own guard sits in `bin.js` rather than in anything a test of
   `application.js` would hit.
2. **`lib/sidebar.rb`'s `-1` clamp.** No longer clamped to `0` before being
   assigned to `browse_view.selection_model.selected`; `start_uri` is guarded
   against the negative-array-index bug that clamp was quietly covering for
   (`docs[-1]` silently returning the *last* page). `FINDINGS.md` #11 records
   what was actually verified against the real GTK4 typelib:
   `GtkSingleSelection:autoselect` (on by default, and never turned off by
   either upstream or this port) reselects row 0 of a non-empty tree no
   matter what is assigned to `selected`, so the on-screen result was never
   actually different — the one place the clamp mattered was `start_uri`,
   which is this port's own addition. `test/drive_sidebar.rb` gained a step
   that builds a second `Sidebar` from a fixture with documentation but no
   Gtk-4.0 node and checks both facts.
3. **The troll gitlink.** `origin/main`'s `troll` submodule, pinned at
   `37b53b29db0b6496f31e13c7f843100db31c9eb1`, is vendored at
   `vendor/troll/` (see `vendor/troll/VENDORED.md`), so
   `lib/theme_selector.rb` and `lib/window_state.rb` can be diffed against
   the files they were actually ported from instead of an unresolvable
   gitlink.
4. **The GSettings schema, only reachable after a manual `rake
   schema:compile`.** `flake.nix`'s package `installPhase` compiled the
   schema only when `data/schemas` already existed in the source tree — which
   it never does, since that directory is `.gitignore`d output of a step
   nobody runs automatically — so a `nix build` shipped *no* compiled schema
   at all. The compile is now unconditional, straight from
   `data/app.gschema.xml`, in both the package build and the devshell's
   `shellHook` (every `nix develop` compiles it fresh, rather than leaving a
   developer to remember the rake task). Verified: `nix develop --command
   bash -c 'gsettings list-schemas'` lists `org.rubygtkproject.Biblioteca`
   with no manual step.

5. **The theme-swatch accessible-label claim was unfalsifiable in-process.**
   `Gtk::Builder` silently accepts a misspelled accessible-property name in
   an `<accessibility>` block — it parses, the button builds, and nothing
   observable in-process distinguishes that from success. `test/drive_biblioteca.rb`
   now asserts the property name `ThemeSelector::BUTTON_UI` actually uses
   against `Gtk::AccessibleProperty.values.map(&:nick)`, GTK's own list, which
   is the one half of this claim a process without AT-SPI can check. The
   other half — that the label itself, not just the property name, actually
   reaches an assistive technology — needs AT-SPI out of process and is not
   done this round; `Can't connect to a11y bus` on every drive run on this
   checkout is the reason, not a choice.

See TEST_PARITY.md and TRANSLATION_PARITY.md for this round's other closes
(`rake default`, CI, `rake data:validate`, TP-1, TP-2) and FINDINGS.md #12 for
an upstream `appstreamcli` finding this round's tooling surfaced.

## Still owed after round 4

Rows 11a and 3 of the round-2 list are paid: the theme selector's three check
buttons carry an `<accessibility>` label (`lib/theme_selector.rb`, closed at
`189b4e6`), and the port has been run (closed at `189b4e6` and `60ee85c`).
What is still owed:

1. The upstream bug report for `FINDINGS.md` #5 (and, lower priority, #6, #11,
   and now #12).
2. `rake data:install` has not been run — the install layout itself (as
   opposed to the four templates `rake data:validate` checks, which now run
   for real) is still unobserved.
3. Nothing drives a pointer or a keyboard. The gesture and middle-click paths
   are reached only through the actions they end in, so the gestures
   themselves — `Gtk::GestureClick` on the two sidebar rows — are still
   unobserved.
4. No Flatpak manifest of any kind exists, so there is nothing for
   `flatpak-builder-lint` to check and no Flatpak build to actually exercise
   the startup-refusal guard the way `src/bin.js:27-32` is exercised upstream
   (inside the sandbox it checks for). Recorded as a gap, not reworded as a
   non-goal.
5. The theme-swatch accessible-label claim (round-2 row 11a): the property
   *name* is now asserted against GTK's own list (round-4 item 5, above), but
   the label itself has still not been verified out-of-band over AT-SPI.

---

## Accountability

`.reports/accountability-ensurance.md` found nine excuse constructions in this
port and drafted a first-person admission for each. Eight of the nine were
answered this round by closing the gap the excuse was covering, not by
rewording it: the theme selector and the window-state saver were rebuilt from
troll's actual source, the schema is shipped, the default URI is derived, the
shortcuts dialog is upstream's widget again. The sentences themselves were
rewritten at the same time — no "deliberate differences", no "the bindings do
not carry", no "worse than the alternative" — and the two binding limitations
that were recorded in the comment describing the gap now live in `FINDINGS.md`
with reproductions. The report's rows stay as they are; they are the record of
what was true at `7211c78`.

One admission is still owed, in first person, because it is still true. The
other two were answered after round 2 by work rather than by rewording; they
are kept here as the record of what was true at `7211c78`, each followed by
what closed it.

> I have not run any of this. The GTK gems are not installed in this checkout,
> so I closed sixteen gaps by reading the upstream source, the bindings' own
> source and the GIR, and not one widget has been drawn. Every row in this
> ledger could be wrong in a way `ruby -c` cannot see — and the riskiest of
> them is `data/ui/shortcuts.ui`, where I am betting that `Gtk::Builder` can
> still instantiate a `GtkShortcutsWindow` that GTK deprecated in 4.18.
> Verified: `ruby -c` on 22 files, `ruby po/extract.rb` (64 messages, 61 of 61
> upstream msgids), 20 of 20 `doc_index_spec.rb` expectations replayed outside
> RSpec.

Closed at `189b4e6` and `60ee85c`. `nix/Gemfile` carries the four runtime gems,
and the application has been run under `xvfb-run`:
`test/drive_biblioteca.rb` walks the whole app for 394 of 394 checks and 18
screenshots and prints `DRIVE OK`, `test/drive_app.rb` runs 31 steps with 2
skipped and `test/drive_sidebar.rb` 24 steps, all three on this checkout. The
bet on `data/ui/shortcuts.ui` came in: `Gtk::Builder` does still instantiate
the deprecated `GtkShortcutsWindow`, and `app.shortcuts` opens it in
`test/drive_app.rb`.

> I did not give the theme selector's three buttons an accessible label, so a
> screen reader reads a tooltip where upstream gives it a label of its own.
> Upstream: `troll/src/widgets/ThemeSelector.blp`, `accessibility { label: … }`
> on each of the three check buttons.
> Port: `lib/theme_selector.rb#button`, tooltip only. Cause and reproduction:
> `FINDINGS.md` #4.

Closed at `189b4e6`. `lib/theme_selector.rb` builds the three check buttons
through `Gtk::Builder` so each one carries upstream's
`accessibility { label: ... }`, because `gtk_accessible_update_property` is
variadic and unbound; the tooltip stays alongside it, as upstream's does.
`test/drive_app.rb` reaches all three buttons and finds three of them, so the
builder string parses and the buttons are real — but GTK4 exposes no getter for
`GTK_ACCESSIBLE_PROPERTY_LABEL`, so the label itself can only be read by an
assistive technology over AT-SPI, and this port has not read it back.

> I found two bugs in upstream and have reported neither. The first moves the
> foreground tab's progress bar from a background tab's load and I diverged
> from upstream to avoid it; the second orphans a Devel build's message
> catalogue and I diverged from that too. Diverging silently and writing it
> down in my own repository is half the job.
> Upstream: `src/window.js:200-233`, `src/main.js:4`.
> Port: `lib/window.rb#on_load_progress` and friends, `lib/package.rb`'s
> `DOMAIN`. Both written up in `FINDINGS.md` #5 and #6; neither filed at
> <https://github.com/workbenchdev/Biblioteca/issues>.
