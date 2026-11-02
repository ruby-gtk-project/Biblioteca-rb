# Component identification — Biblioteca / Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4ededb8dff1b537de09d25ce2e55d1997c43d3` (`9e4eded`) |
| Port | `ruby` @ `d63ee497e572c2d5ef7ab7790ef119be3371f9ed` (`d63ee49`) |
| Scanner | `.claude/skills/component-identification/scripts/component-scan.sh` |
| Upstream rows | 154 |
| Port rows | 175 |
| Scanned | 2026-11-02 |

Both trees were scanned and both were then read. The scan is a lead, not a
verdict: on the upstream side it double-counts a `.blp` template root against
its JS class, and on the port side it reads widget and enum names out of
comments and heredocs. Every count below that differs between the two sides
was resolved by opening the files.

## Step 1 — the template files, which are the unit list

Upstream builds its UI from six Blueprint templates plus three `menu`/UI
blocks:

| Template | Root type | Owning JS |
|---|---|---|
| `src/window.blp` | `Adw.ApplicationWindow` | `src/window.js` |
| `src/FindOverlay.blp` | `Gtk.Overlay` | `src/FindOverlay.js` |
| `src/WebView.blp` | `WebKit.WebView` | `src/WebView.js` |
| `src/Shortcuts.blp` | `Gtk.ShortcutsWindow` (not a template — a named object) | `src/Shortcuts.js` |
| `src/sidebar/Sidebar.blp` | `Adw.NavigationPage` + `menu menu_app` | `src/sidebar/Sidebar.js` |
| `src/sidebar/BrowseView.blp` | `Gtk.ScrolledWindow` | `src/sidebar/BrowseView.js` |
| `src/sidebar/SearchView.blp` | `Gtk.ScrolledWindow` | `src/sidebar/SearchView.js` |
| `src/sidebar/ZoomButtons.blp` | `Gtk.Box` | `src/sidebar/ZoomButtons.js` |

The port has **one** UI file, `data/ui/shortcuts.ui` (a GtkBuilder translation
of `src/Shortcuts.blp`, kept because `GtkShortcutsWindow` has no usable Ruby
constructor — `FINDINGS.md` #7). Everything else is built as memoized
widget methods, which is the house style.

Two upstream dependencies are **git submodules and are not present on
`origin/main`**: `troll/` (a gitlink) and the `src/biblioteca` launcher's
`@app_id@` substitution. `troll/src/widgets/ThemeSelector.{js,blp,css}` and
`troll/src/util.js`'s `persistWindowState` are therefore *not readable from the
pinned upstream ref*. The port carries `lib/theme_selector.rb` and
`lib/window_state.rb` against them, and **their parity cannot be verified from
`origin/main` at all.** That is a hole in this audit, not a pass.

## Step 2 — file mapping

```
src/bin.js + src/main.js + src/init.js + src/application.js + src/actions.js
                                            -> lib/biblioteca/application.rb
                                               lib/package.rb
src/util.js + data/app.gschema.xml          -> lib/settings.rb
src/about.js                                -> lib/about_dialog.rb
src/style.css                               -> lib/style.rb
src/window.blp + src/window.js              -> lib/window.rb
troll/src/util.js (persistWindowState)      -> lib/window_state.rb        [unreadable upstream]
src/Shortcuts.blp + src/Shortcuts.js        -> data/ui/shortcuts.ui
                                               lib/shortcuts_window.rb
src/FindOverlay.blp + src/FindOverlay.js    -> lib/find_overlay.rb
src/WebView.blp + src/WebView.js            -> lib/web_view.rb
src/sidebar/Sidebar.blp + Sidebar.js        -> lib/sidebar.rb
  menu menu_app (in Sidebar.blp)            -> lib/sidebar_menu.rb
troll/src/widgets/ThemeSelector.*           -> lib/theme_selector.rb      [unreadable upstream]
src/sidebar/ZoomButtons.blp + .js           -> lib/zoom_buttons.rb
src/sidebar/BrowseView.blp + .js            -> lib/browse_view.rb
src/sidebar/SearchView.blp + .js            -> lib/search_view.rb
src/sidebar/DocumentationPage.js            -> lib/documentation_page.rb
src/sidebar/fzy.js                          -> lib/fzy.rb
build-aux/build-index.js                    -> lib/doc_index.rb
data/*                                      -> data/*
src/icons/*.svg                             -> data/icons/hicolor/scalable/actions/*.svg
```

Upstream files with **no** port file opposite them:

| Upstream | What it is |
|---|---|
| `meson.build`, `meson_options.txt`, `data/meson.build`, `src/meson.build` | the build system — the port is a gem (`biblioteca-rb.gemspec`, `rakelib/biblioteca.rake`) |
| `build-aux/app.drey.Biblioteca.json`, `.Devel.json`, `build-aux/modules/*.json` | the Flatpak manifests. **Nothing in the port corresponds.** |
| `src/biblioteca` | shell launcher forcing `LANG=en_US.UTF-8`; `exe/biblioteca` replaces it and deliberately does not force a locale |
| `Makefile`, `package.json`, `.eslintrc.yaml`, `.husky/pre-commit` | the lint/CI harness; RuboCop + `.gitlab-ci.yml` stand in |
| `troll/` | submodule, unreadable |

## Step 3 — the inventory

### `src/window.blp` + `src/window.js` → `lib/window.rb`

Widgets (upstream count, after striking the template root's double count):
`Adw.ApplicationWindow` 1, `Adw.TabOverview` 1, `Adw.OverlaySplitView` 1,
`Adw.NavigationPage` 1, `Adw.BreakpointBin` 1, `Adw.ToolbarView` 1,
`Adw.HeaderBar` 1, `Adw.WindowTitle` 1, `Adw.Clamp` 1, `Adw.TabBar` 1,
`Adw.TabButton` 1, `Adw.TabView` 1, `Gtk.Box` 2, `Gtk.Button` 3,
`Gtk.ToggleButton` 1, `Gtk.Entry` 1, `Gtk.ProgressBar` 1, `Gtk.ActionBar` 1,
`Gtk.StackPage` 2 (a `Gtk.Stack` with two pages).

CSS: `main-window` 1, `flat` 4, `osd` 1, `devel` 1 (runtime).
Actions installed on `win`: `new-tab` (parameter `s`), `close-tab`,
`navigation-forward`, `navigation-back`, `zoom-in`, `zoom-out`, `reset-zoom`,
`global-search`, `focus-urlbar`, `toggle-sidebar`, `toggle-overview`,
`update-buttons`, `find`, `find-prev`, `find-next`, `close-find` — 16.
Actions targeted from the markup: `win.navigation-back`,
`win.navigation-forward`, `win.new-tab` (with target).
Signals: `clicked`, `create-tab`, `notify::selected-page`, `apply`, `unapply`,
`activate` (url bar), `notify::is-online`, `notify::estimated-load-progress`,
`load-changed`; plus five `bind_property` / `bind_property_full` bindings
(title→tab, title→content page, title→window, zoom-level→zoom row, uri→url bar).
Breakpoints: 2 (`max-width: 850sp`, `max-width: 450sp`), the first also
carrying `add_setters` on the two sidebar views' `width-request`.

Port: `lib/window.rb` builds all of the above. The scan's three deltas are
artifacts — `Adw.NavigationPage` 1→2 and `Gtk.ApplicationWindow` 0→1 are
comment text, `Gtk.Stack` 0→1 is the `Gtk.StackPage` pair spelled as
`Gtk::Stack` + two `add_named` calls, `Adw.Breakpoint` 2→3 is a comment.
`win.*` action count is 16 (`ACTIONS` is 15 plus `add_new_tab_action`).
`notify::is-online` has no counterpart signal — the port passes
`on_online_changed:` into `WebView.new` (`lib/web_view.rb:150`,
`lib/window.rb:173`) and fires it from `#update_is_online`. Located.

### `src/FindOverlay.blp` + `.js` → `lib/find_overlay.rb`

`Gtk.Overlay` 1, `Gtk.SearchBar` 1, `Gtk.Box` 4, `Gtk.Image` 1, `Gtk.Text` 1,
`Gtk.Label` 1, `Gtk.Button` 3. CSS `searchbar`, `linked`, `circular`.
`css-name: "entry"` on the inner box. Actions targeted:
`win.find-prev`, `win.find-next`, `win.close-find`. Signals: `found-text`,
`failed-to-find-text`, `notify::text`, plus `connect_entry`.
Port matches, with the `css-name: entry` box built through a 20-line
`Gtk::Builder` string because `css-name` is construct-only (`FINDINGS.md` #3).

### `src/WebView.blp` + `.js` → `lib/web_view.rb`

`WebKit.WebView` 1 with `WebKit.Settings`
(`enable-back-forward-navigation-gestures`, `enable-developer-extras: false`,
`enable-smooth-scrolling`). One `UserScript`, two `UserStyleSheet`s, 11
`ContextMenuAction`s pruned, `notify::uri`, `decide-policy`, `context-menu`,
`changed` on the back/forward list, `win.new-tab` and `win.update-buttons`
fired. Port matches 1:1; the nine `WebKit.*` enum rows the scan reports as
missing are Ruby symbols (`:all_frames`, `:user`, `:end`, `:navigation_action`)
and a symbol array of the same 11 context-menu actions.

### `src/sidebar/Sidebar.blp` + `.js` → `lib/sidebar.rb` + `lib/sidebar_menu.rb`

`Adw.NavigationPage` 1, `Adw.ToolbarView` 1, `Adw.HeaderBar` 1,
`Gtk.MenuButton` 1 (`primary: true`), `Gtk.Box` 1 (`toolbar`),
`Gtk.SearchEntry` 1 (`search-delay: 200`), `Gtk.Stack` 1
(`transition-type: none`), `Adw.StatusPage` 1 (`compact`).
`menu menu_app`: 4 sections — a `custom: "themeswitcher"` item, a
`custom: "zoom_buttons"` item, a `Bookmarks` submenu of 8 items each firing
`win.new-tab` with a target, and `app.shortcuts` + `app.about`.
Port matches. The scan's `app.about` 1→0, `app.shortcuts` 1→0 and
`win.new-tab` 8→0 are artifacts of `lib/sidebar_menu.rb:72` interpolating the
target into `"win.new-tab('#{uri}')"`; the literals are there on reading.

### `src/sidebar/BrowseView.blp` + `.js` → `lib/browse_view.rb`

`Gtk.ScrolledWindow` 1 (`width-request: 400`), `Gtk.ListView` 1
(`navigation-sidebar`, `enable-rubberband: false`), a row factory producing
`Gtk.TreeExpander` + `Gtk.Inscription` (`nat-chars: 10`,
`ellipsize_end`). Model chain `Gio.ListStore` → `Gtk.TreeListModel`
(passthrough false, autoexpand false) → `Gtk.SingleSelection`
(`can_unselect`). Controller `Gtk.GestureClick` (`button: 0`) → `pressed`.
Signals `activate`, `selection-changed`, `value-changed` (vadjustment),
`notify::uri` (on the web view), `notify::webview` (own property).
Port matches; `Gtk.BuilderListItemFactory` → `Gtk.SignalListItemFactory`
(`setup`/`bind`) is the documented correspondence for a `.blp`-less port.

### `src/sidebar/SearchView.blp` + `.js` → `lib/search_view.rb`

`Gtk.ScrolledWindow` 1, `Gtk.ListView` 1 (`navigation-sidebar`), a row factory
producing `Gtk.Box` + `Gtk.Inscription` (`nat-chars: 25`) + an insensitive
`Gtk.Button` carrying `pill small doc-tag`. Controller `Gtk.GestureClick`
(`button: 0`). Signals `pressed`, `selection-changed`,
`notify::search-term`, custom signal `search-view-selection-changed`.
Port matches on widgets, CSS and the gesture. The model chain is **replaced**:
`Gtk.CustomFilter` + `Gtk.FilterListModel` + `Gtk.CustomSorter` +
`Gtk.SortListModel` become a Ruby `filter_map`/`sort_by` spliced into a plain
`Gio::ListStore` (`lib/search_view.rb#rank`, `#refresh_results`), because
`GtkCustomSortFunc` reaches Ruby as a pair of addresses (`FINDINGS.md` #1).
That is a data-plumbing correspondence; the behaviour is located.
`notify::search-term` → the `search_term=` setter; the custom signal → the
`on_selected:` callback (`lib/sidebar.rb:49`). Located.

### `src/sidebar/ZoomButtons.blp` + `.js` → `lib/zoom_buttons.rb`

`Gtk.Box` 1 (`homogeneous`), `Gtk.Button` 2 (`flat circular` each),
`Gtk.Label` 1 (`"100%"`). `win.zoom-out`, `win.zoom-in`. `zoom-level`
property bound to the label. Port matches; the property is a plain
accessor driven from `lib/window.rb#on_zoom_changed`.

### `src/Shortcuts.blp` + `.js` → `data/ui/shortcuts.ui` + `lib/shortcuts_window.rb`

`Gtk.ShortcutsWindow` 1 (`modal`, `hide-on-close`), `Gtk.ShortcutsSection` 1,
`Gtk.ShortcutsGroup` 4 (Tabs, Navigation, Zoom, General),
`Gtk.ShortcutsShortcut` 26 — 24 with an accelerator, 2 with
`shortcut-type: gesture_two_finger_swipe_*`. Port: identical counts, and the
24 accelerator strings are byte-identical (diffed, including upstream's
`<Ctrl>Home` typo at `src/Shortcuts.blp:36`, kept on purpose —
`FINDINGS.md` #8). `app.shortcuts` + 15 `set_accels_for_action` calls land in
`lib/shortcuts_window.rb#accels`, which also picks up `app.quit` from
`src/actions.js`.

### `src/application.js` + `actions.js` + `about.js` + `bin.js` + `main.js` + `init.js`

`Adw.Application` (`resource_base_path`), `set_option_context_description`,
`Adw.StyleManager` + `changed::color-scheme`, `activate` building one window,
app actions `quit` / `about` / `settings.create_action("color-scheme")`,
`<Control>Q`, `Adw.AboutDialog` with 8 fields + `add_credit_section`,
`GLib.set_application_name`, `pkg.initGettext`, the Flatpak guard, and
`Gio._promisify(Gtk.UriLauncher.prototype, "launch", ...)`.

Port: `lib/biblioteca/application.rb` + `lib/package.rb` +
`lib/about_dialog.rb` + `lib/settings.rb`. Two upstream items have **no
located counterpart** and are carried to `component-parity.md` as gaps:

* `src/bin.js:27-32`, the Flatpak-required guard and its error message;
* `src/init.js:8`, `Gtk.UriLauncher`.
