# Component inventory — Biblioteca → Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` (GJS + Blueprint) |
| Port | `ruby` branch, `lib/` |
| Method | `.claude/skills/component-identification` — declarative files first (`.blp`, `menu`, `.ui`), then every backing `.js`, then the port side read file by file |
| Surveyed | 2026-11-02 |

Upstream splits each component across a `.blp` template and a `.js` class, so a
component here is **the set of files**, unioned before comparison. The port's
house style puts the whole component in one `lib/<thing>.rb` with memoized
widget accessors, so the mapping is many-to-one in the port's favour.

Two upstream dependencies are **git submodules, absent from `origin/main`**:
`troll/` (gitlink `37b53b2`) and therefore
`troll/src/widgets/ThemeSelector.{js,blp,css}` and `persistWindowState` in
`troll/src/util.js`. The port carries `lib/theme_selector.rb` and
`lib/window_state.rb` against them. Their parity **cannot be verified from the
pinned upstream ref** — that is a hole in this survey, not a pass.

Upstream has **no `po/` catalogue at all** (no `po/`, no `LINGUAS`, no `.po`);
translatable strings exist only as `_("…")` in the `.blp` files and `gettext`
imports in the `.js`. The port adds `po/POTFILES.in`, `po/extract.rb` and
`po/org.rubygtkproject.Biblioteca.pot` — an addition, not a gap.

## Declarative unit list (the component boundaries)

| Declarative file | Root | Kind of root | Backing source |
|---|---|---|---|
| `src/window.blp` | `template $Window: Adw.ApplicationWindow` | template | `src/window.js` |
| `src/sidebar/Sidebar.blp` | `template $Sidebar: Adw.NavigationPage` + `menu menu_app` | template + menu model | `src/sidebar/Sidebar.js` |
| `src/sidebar/BrowseView.blp` | `template $BrowseView: ScrolledWindow` | template | `src/sidebar/BrowseView.js` |
| `src/sidebar/SearchView.blp` | `template $SearchView: ScrolledWindow` | template | `src/sidebar/SearchView.js` |
| `src/sidebar/ZoomButtons.blp` | `template $ZoomButtons: Gtk.Box` | template | `src/sidebar/ZoomButtons.js` |
| `src/FindOverlay.blp` | `template $FindOverlay: Gtk.Overlay` | template | `src/FindOverlay.js` |
| `src/WebView.blp` | `template $WebView: WebKit.WebView` | template | `src/WebView.js` |
| `src/Shortcuts.blp` | `ShortcutsWindow window_shortcuts` | **named object, not a template** | `src/Shortcuts.js` |

The port has exactly one UI file, `data/ui/shortcuts.ui` — a GtkBuilder
translation of `src/Shortcuts.blp`, kept because `GtkShortcutsWindow` has no
usable Ruby constructor (`FINDINGS.md` #7). Everything else is memoized
widget methods.

## Component list

Ordered as a user meets them: application, window, sidebar and its views, the
menu surfaces, the per-tab widgets, then the dialogs and the non-widget units.

| # | Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---:|---|---|---|---|
| 1 | `src/application.js`, `src/actions.js`, `src/main.js`, `src/init.js`, startup half of `src/bin.js` | `lib/biblioteca/application.rb` | application (actions, style manager, activation) | yes |
| 2 | `src/bin.js` (`imports.package.init`, `GLib.set_application_name`), `src/main.js` (`pkg.initGettext`) | `lib/package.rb` | app-id / paths / gettext singleton | yes |
| 3 | `data/app.gschema.xml`, `src/util.js` (`settings`) | `lib/settings.rb` | GSettings wrapper (5 keys) | yes |
| 4 | `src/style.css` | `lib/style.rb` | stylesheet (`#top-toolbars`, `.searchbar`, `button.pill.small`) | yes |
| 5 | `src/window.blp` + `src/window.js` | `lib/window.rb` | main window: tab overview, split view, header bar, URL bar, tab bar, load bar, bottom toolbar, 2 breakpoints, 16 `win.*` actions | yes |
| 6 | `troll/src/util.js` (`persistWindowState`) | `lib/window_state.rb` | window-geometry persistence | yes (upstream unreadable) |
| 7 | `src/sidebar/Sidebar.blp` (template) + `src/sidebar/Sidebar.js` | `lib/sidebar.rb` | sidebar navigation page: header bar, menu button, search entry, stack, index load | yes |
| 8 | `menu menu_app` in `src/sidebar/Sidebar.blp` | `lib/sidebar_menu.rb` | menu model: 4 sections, 2 custom slots, Bookmarks submenu (8 items), Shortcuts + About | yes |
| 9 | `troll/src/widgets/ThemeSelector.{js,blp,css}` | `lib/theme_selector.rb` | menu popover widget: 3-way theme switch (`themeswitcher` slot) | yes (upstream unreadable) |
| 10 | `src/sidebar/ZoomButtons.blp` + `.js` | `lib/zoom_buttons.rb` | menu popover widget: zoom out / level / zoom in (`zoom_buttons` slot) | yes |
| 11 | `src/sidebar/BrowseView.blp` + `.js` | `lib/browse_view.rb` | sidebar page: documentation tree (`ListView` + `TreeExpander` rows) | yes |
| 12 | `src/sidebar/SearchView.blp` + `.js` | `lib/search_view.rb` | sidebar page: fuzzy results (`ListView` + tag-pill rows) | yes |
| 13 | `Adw.StatusPage status_page` in `src/sidebar/Sidebar.blp` | `lib/sidebar.rb#status_page` | **empty state** — "No Results Found" | yes |
| 14 | `src/sidebar/DocumentationPage.js` | `lib/documentation_page.rb` | model object (name/tag/search_name/score/uri/children) | yes |
| 15 | `src/sidebar/fzy.js` | `lib/fzy.rb` | fuzzy matcher (vendored fzy.js) | yes |
| 16 | `src/FindOverlay.blp` + `.js` | `lib/find_overlay.rb` | find-in-page overlay bar + match counter | yes |
| 17 | `src/WebView.blp` + `.js` | `lib/web_view.rb` | per-tab web view, user script/styles, context-menu pruning, middle-click new tab | yes |
| 18 | `src/Shortcuts.blp` + `src/Shortcuts.js` | `data/ui/shortcuts.ui` + `lib/shortcuts_window.rb` | keyboard-shortcuts window (4 groups, 26 shortcuts) + all accelerators | yes |
| 19 | `src/about.js` | `lib/about_dialog.rb` | About dialog + Contributors credit section | yes |
| 20 | `build-aux/build-index.js` | `lib/doc_index.rb` | build-time `doc-index.json` generator the sidebar tree reads | yes |

Every user-facing component upstream has a port file. **Nothing in the list is
missing.**

## Per-component detail

### 1–4 Application, package, settings, style

`Adw.Application` with `resource_base_path`,
`set_option_context_description("<https://biblioteca.sonny.re>")`, one window
per activation, `Adw.StyleManager` driven by `changed::color-scheme`.
App actions: `quit` (`<Control>Q`), `about`,
`settings.create_action("color-scheme")` (stateful, drives the theme
selector), and `shortcuts` (`<Control>question`, installed from
`src/Shortcuts.js`). Settings keys: `color-scheme` (i, 0), `window-width`,
`window-height` (i, 0), `window-maximized`, `window-fullscreened` (b, false).
CSS classes defined by the stylesheet: `searchbar`, `pill small` (on
`button`), plus the `#top-toolbars` name selector.

Two upstream startup behaviours have **no located counterpart** and are
carried as gaps, not components: `src/bin.js:27-32`'s Flatpak-required guard
(documented at `lib/package.rb:20-21`) and `src/init.js:8`'s
`Gio._promisify(Gtk.UriLauncher…)`.

### 5 Window — `lib/window.rb`

Widgets: `Adw.ApplicationWindow` 1 (`main-window`, plus `devel` at runtime),
`Adw.TabOverview` 1 (`enable-new-tab`), `Adw.OverlaySplitView` 1,
`Adw.NavigationPage` 1 ("Documentation"), `Adw.BreakpointBin` 1,
`Adw.ToolbarView` 1, `Gtk.Box` 2 (`top-toolbars`, `box_navigation`),
`Adw.HeaderBar` 1, `Gtk.Stack` 1 with 2 `StackPage`s (`title`, `url_bar`),
`Adw.WindowTitle` 1, `Adw.Clamp` 1, `Gtk.Entry` 1 (`input-purpose: url`),
`Gtk.ToggleButton` 1 (`flat`, sidebar), `Gtk.Button` 3 (back, forward, new
tab — all `flat`), `Adw.TabBar` 1, `Gtk.ProgressBar` 1 (`osd`),
`Gtk.ActionBar` 1, `Adw.TabButton` 1, `Adw.TabView` 1 (`shortcuts: all`).

Actions installed on the `win` group (16): `new-tab` (param `s`), `close-tab`,
`navigation-forward`, `navigation-back`, `zoom-in`, `zoom-out`, `reset-zoom`,
`global-search`, `focus-urlbar`, `toggle-sidebar`, `toggle-overview`,
`update-buttons`, `find`, `find-prev`, `find-next`, `close-find`. Targeted
from markup: `win.navigation-back`, `win.navigation-forward`, `win.new-tab`
with a URI target.

Signals: `clicked` (tab button), `create-tab`, `notify::selected-page`,
`apply`/`unapply` on the 450sp breakpoint (moves the navigation box between
header bar and bottom bar), `activate` (URL bar), `notify::is-online`,
`notify::estimated-load-progress`, `load-changed`. Five property bindings:
title→tab page, title→content page, title→window, zoom-level→zoom row,
uri→URL bar buffer.

Breakpoints: `max-width: 850sp` (collapses the split view, shows the sidebar
button, `add_setters` the two sidebar views' `width-request` to 300) and
`max-width: 450sp` (shows the bottom toolbar and tab button, hides the new-tab
button and tab bar).

Repeater: one `FindOverlay`+`WebView` pair per tab, variable count, driven by
`win.new-tab`. Port: all present. `notify::is-online` is located as an
`on_online_changed:` callback passed into `WebView.new`.

### 7–8, 13 Sidebar, its menu and its empty state

`Adw.NavigationPage` 1 (title "Biblioteca"), `Adw.ToolbarView` 1,
`Adw.HeaderBar` 1, `Gtk.MenuButton` 1 (`open-menu-symbolic`, `primary: true`,
"Main Menu"), `Gtk.Box` 1 (`toolbar`), `Gtk.SearchEntry` 1
(`search-delay: 200`, "Search Biblioteca"), `Gtk.Stack` 1
(`transition-type: none`) holding the browse view, the search view and
`Adw.StatusPage` 1 (`compact`, `edit-find-symbolic`, "No Results Found" /
"Try a different search term"). Signals: `search-changed`,
`notify::webview`, `search-view-selection-changed`.

Menu: section 1 `custom: "themeswitcher"`; section 2
`custom: "zoom_buttons"`; section 3 a "Bookmarks" submenu of 8
`win.new-tab` items (Developer Documentation, HIG, JavaScript, Vala, Rust,
Python, Blueprint, DevDocs); section 4 `app.shortcuts` and `app.about`. Both
`custom:` slots are component boundaries filled from source
(`popover.add_child`).

### 9–10 Theme selector and zoom row

Theme selector: 3 `Gtk.CheckButton`s on `app.color-scheme` targets, three
style classes, its own CSS — all from the unreadable `troll` submodule.
Zoom row: `Gtk.Box` (`homogeneous`) + 2 `Gtk.Button` (`flat circular`,
`win.zoom-out` / `win.zoom-in`) + `Gtk.Label` ("100%") bound to `zoom-level`.

### 11–12, 14–15 Browse view, search view, model, matcher

Browse view: `Gtk.ScrolledWindow` (`width-request: 400`), `Gtk.ListView`
(`navigation-sidebar`, `enable-rubberband: false`), rows of
`Gtk.TreeExpander` + `Gtk.Inscription` (`nat-chars: 10`, `ellipsize_end`).
Model chain `Gio.ListStore` → `Gtk.TreeListModel` → `Gtk.SingleSelection`
(`can_unselect`). Controller `Gtk.GestureClick` (`button: 0`) → middle-click
opens a new tab. Signals `activate` (toggles expansion),
`selection-changed` (loads the URI), `value-changed` on the vadjustment
(scroll correction, `ITEM_HEIGHT` 38).

Search view: same shell; rows are `Gtk.Box` + `Gtk.Inscription`
(`nat-chars: 25`) + an insensitive `Gtk.Button` carrying
`pill small doc-tag`. Upstream filters with `Gtk.CustomFilter` +
`FilterListModel` + `CustomSorter` + `SortListModel` and a
`type:` query prefix over 19 symbol kinds; the port replaces the model chain
with Ruby `filter_map`/`sort_by` into a plain `Gio::ListStore` because
`GtkCustomSortFunc` is unusable from Ruby (`FINDINGS.md` #1). Behaviour is
located, plumbing differs.

`DocumentationPage`: 6 fields (`name`, `tag`, `search_name`, `score`, `uri`,
`children`) — GObject properties upstream, plain accessors in the port
because the port has no `BuilderListItemFactory` bind expressions.

### 16–17 Find overlay and web view

Find overlay: `Gtk.Overlay` 1, `Gtk.SearchBar` 1 (`searchbar`), `Gtk.Box` 4
(one with `css-name: "entry"`, one `linked`), `Gtk.Image` 1
(`edit-find-symbolic`), `Gtk.Text` 1 (10 chars), `Gtk.Label` 1 ("N of M",
opacity 0.5), `Gtk.Button` 3 (`win.find-prev`, `win.find-next`,
`win.close-find`; the last `circular`). Signals `found-text`,
`failed-to-find-text`, `notify::text`, plus `connect_entry`. The
`css-name` box is built through a small `Gtk::Builder` string in the port
because `css-name` is construct-only (`FINDINGS.md` #3).

Web view: `WebKit.WebView` + `WebKit.Settings`
(back/forward gestures on, developer extras off, smooth scrolling on), one
`UserScript` (overshoot overlay), two `UserStyleSheet`s (devhelp sidebar
hidden, overshoot gradients), 11 `ContextMenuAction`s pruned, `notify::uri` →
`is-online`, `decide-policy` (middle-click → `win.new-tab`), `context-menu`,
and `changed` on the back/forward list → `win.update-buttons`.

### 18–19 Shortcuts window and About dialog

Shortcuts: `Gtk.ShortcutsWindow` 1, `Gtk.ShortcutsSection` 1,
`Gtk.ShortcutsGroup` 4 (Tabs 12, Navigation 9, Zoom 3, General 2),
`Gtk.ShortcutsShortcut` 26 — 24 accelerators plus 2
`gesture_two_finger_swipe_{left,right}` entries. 15
`set_accels_for_action` calls bind the `win.*` accelerators; upstream's
`<Ctrl>Home` typo at `src/Shortcuts.blp:36` is reproduced deliberately
(`FINDINGS.md` #8).

About: `Adw.AboutDialog` with application name, developer name, copyright,
`GPL_3_0_ONLY`, version, website, application icon, issue URL, 2 developers,
1 artist, plus an added "Contributors" credit section of 2.

### 20 Doc index

`build-aux/build-index.js` runs under gjs at install time and writes
`doc-index.json` into pkgdatadir; `lib/doc_index.rb` is the Ruby equivalent
and also supplies `default_root` / the fallback URI the window opens with.
Not a widget, but the sidebar tree does not exist without it.

## Non-component upstream files (no port counterpart, by design)

| Upstream | Why there is none |
|---|---|
| `meson.build`, `meson_options.txt`, `data/meson.build`, `src/meson.build` | the port is a gem — `biblioteca-rb.gemspec`, `rakelib/` |
| `build-aux/app.drey.Biblioteca{,.Devel}.json`, `build-aux/modules/*.json` | Flatpak manifests; nothing corresponds |
| `src/biblioteca` | shell launcher forcing `LANG=en_US.UTF-8`; `exe/biblioteca` replaces it and deliberately does not force a locale |
| `Makefile`, `package.json`, `.eslintrc.yaml`, `.prettierignore`, `.husky/pre-commit`, `.vscode/*` | JS lint/CI harness; RuboCop + `.gitlab-ci.yml` stand in |
| `troll/` | submodule, not present on `origin/main` |
| `Biblioteca.doap`, `COPYING`, `CONTRIBUTING.md`, `README.md` | project metadata |

Data files are ported rather than mapped to `lib/`: `data/app.desktop`,
`data/app.gschema.xml`, `data/app.metainfo.xml`, `data/app.service`,
`data/screenshot.png` and the icon tree all exist on `ruby`, with
`app.drey.Biblioteca` rewritten to `org.rubygtkproject.Biblioteca`. The seven
`src/icons/*.svg` are installed under
`data/icons/hicolor/scalable/actions/`.

## Open risks

1. `lib/theme_selector.rb` and `lib/window_state.rb` are ported against a
   submodule that is not in the pinned upstream ref. Unverifiable here.
2. `src/bin.js`'s Flatpak guard and `src/init.js`'s `Gtk.UriLauncher`
   promisify have no counterpart.
3. The search view's model chain is a behavioural, not structural,
   correspondence (`FINDINGS.md` #1) — it needs test parity, not inventory
   parity, to be trusted.
