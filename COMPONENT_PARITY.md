# Component parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` |
| Source of the gap list | `.reports/component-parity.md` (audited at `7211c78`) |
| Identification | `.reports/component-identification.md` |

This is the port's own ledger, appended to as units land. `.reports/` is an
audit of the port; this file is what the port owes and what it has paid.

**Verification status, stated once and applying to every row below:** no row in
this file has been exercised in a running GTK process. The `gtk4`, `adwaita`,
`webkit-gtk` and `gettext` gems are not installed in this checkout
(`bundle exec ruby -e 'require "gtk4"'` raises `LoadError`), so every claim
here rests on reading the upstream source, reading the bindings' own source and
GIR, and `ruby -c`. Each row says which API calls in it are unverified at
runtime.

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
| 11a | theme-selector buttons have no accessible label | **open** |
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

#### 11a — open: the accessible labels

`ThemeSelector.blp` gives each button an `accessibility { label: … }` block as
well as a tooltip. This port sets the tooltip only, so a screen reader
announces the tooltip rather than a dedicated accessible label. Cause and
reproduction: `FINDINGS.md` #4.

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

## Still owed after round 2

1. Row 11a: the theme selector's accessible labels.
2. The upstream bug report for `FINDINGS.md` #5 (and, lower priority, #6).
3. A run. Nothing in this ledger has been seen working, because the GTK gems
   are not installed in this checkout. Every row above is a reading of the
   upstream source and of the bindings, not an observation.

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

Three admissions are still owed, in first person, because they are still true:

> I have not run any of this. The GTK gems are not installed in this checkout,
> so I closed sixteen gaps by reading the upstream source, the bindings' own
> source and the GIR, and not one widget has been drawn. Every row in this
> ledger could be wrong in a way `ruby -c` cannot see — and the riskiest of
> them is `data/ui/shortcuts.ui`, where I am betting that `Gtk::Builder` can
> still instantiate a `GtkShortcutsWindow` that GTK deprecated in 4.18.
> Verified: `ruby -c` on 22 files, `ruby po/extract.rb` (64 messages, 61 of 61
> upstream msgids), 20 of 20 `doc_index_spec.rb` expectations replayed outside
> RSpec.

> I did not give the theme selector's three buttons an accessible label, so a
> screen reader reads a tooltip where upstream gives it a label of its own.
> Upstream: `troll/src/widgets/ThemeSelector.blp`, `accessibility { label: … }`
> on each of the three check buttons.
> Port: `lib/theme_selector.rb#button`, tooltip only. Cause and reproduction:
> `FINDINGS.md` #4.

> I found two bugs in upstream and have reported neither. The first moves the
> foreground tab's progress bar from a background tab's load and I diverged
> from upstream to avoid it; the second orphans a Devel build's message
> catalogue and I diverged from that too. Diverging silently and writing it
> down in my own repository is half the job.
> Upstream: `src/window.js:200-233`, `src/main.js:4`.
> Port: `lib/window.rb#on_load_progress` and friends, `lib/package.rb`'s
> `DOMAIN`. Both written up in `FINDINGS.md` #5 and #6; neither filed at
> <https://github.com/workbenchdev/Biblioteca/issues>.
