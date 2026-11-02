# Component identification — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` (GJS + blueprint + WebKitGTK 6.0) |
| Port | `ruby` @ `7211c78` |
| Scan | `.claude/skills/component-identification/scripts/component-scan.sh` |

The earlier `.reports/component-inventory.md` was written against a `ruby`
branch that had three `.rb` files and no UI. Commit `7211c78` landed 18 more.
That file is now **stale** on every `**present: no**` line; this document is the
re-identification.

## Whole-app totals

| Axis | Upstream distinct | Port distinct |
|---|---:|---:|
| Widget types | 35 | 40 |
| CSS classes | 13 | 14 |
| Signals | 25 | 30 |
| Actions (literal) | 16 | 14 |
| Controllers | 1 | 1 |
| Scan rows | 154 | 163 |

Unlike the usual shape of a young port, the port's rows are *higher* than
upstream's on three axes. That is the house style's declarative rebuild: a
widget upstream declared once in a `.blp` is a memoized method plus a `tap`
here, and a property binding upstream wrote once is two `notify::` handlers.
It is not evidence of parity — see `component-parity.md`, where the gaps are
all in the files that produce no scan rows at all (`data/`, `po/`, icons).

## File mapping (upstream unit → port file)

| Upstream | Port |
|---|---|
| `src/window.blp` + `src/window.js` | `lib/window.rb` |
| `src/sidebar/Sidebar.blp` (template) + `src/sidebar/Sidebar.js` | `lib/sidebar.rb` |
| `menu menu_app` in `src/sidebar/Sidebar.blp` | `lib/sidebar_menu.rb` |
| `src/sidebar/BrowseView.blp` + `.js` | `lib/browse_view.rb` |
| `src/sidebar/SearchView.blp` + `.js` | `lib/search_view.rb` |
| `src/sidebar/DocumentationPage.js` | `lib/documentation_page.rb` |
| `src/sidebar/ZoomButtons.blp` + `.js` | `lib/zoom_buttons.rb` |
| `src/sidebar/fzy.js` | `lib/fzy.rb` |
| `src/WebView.blp` + `.js` | `lib/web_view.rb` |
| `src/FindOverlay.blp` + `.js` | `lib/find_overlay.rb` |
| `src/Shortcuts.blp` + `src/Shortcuts.js` | `lib/shortcuts_window.rb` |
| `src/about.js` | `lib/about_dialog.rb` |
| `src/application.js` + `actions.js` + `main.js` + `init.js` + `bin.js` | `lib/biblioteca/application.rb` |
| `src/style.css` | `lib/style.rb` |
| `src/util.js` (`settings`) + `data/app.gschema.xml` | `lib/settings.rb` |
| `troll/src/widgets/ThemeSelector.js` | `lib/theme_selector.rb` |
| `troll/src/util.js` (`persistWindowState`) | `lib/window_state.rb` |
| `build-aux/build-index.js` | `lib/doc_index.rb` |
| `data/app.desktop` | **nothing** |
| `data/app.metainfo.xml` | **nothing** |
| `data/app.service` | **nothing** |
| `data/icons/**` (5 files) | **nothing** |
| `src/icons/*.svg` (7 files) | **nothing** |
| `src/biblioteca` (LANG wrapper) | **nothing** |

The last seven rows are the whole finding of this inventory: every unit that
is a *widget* has a port file, and every unit that is *data* has none. Those
rows produce no scan rows on either side, which is exactly why a scan-only
review reads this port as finished.

## Units

### `lib/window.rb` — the application window

| Widget | Up × | Port × | CSS | Signals / actions |
|---|---:|---:|---|---|
| `Adw.ApplicationWindow` | 1 | 1 | `main-window`, `devel` | — |
| `Adw.Breakpoint` | 2 | 2 | — | `apply`, `unapply` (port); `setters` (upstream) |
| `Adw.TabOverview` | 1 | 1 | — | `create-tab` |
| `Adw.OverlaySplitView` | 1 | 1 | — | `notify::show-sidebar` (port only) |
| `Adw.NavigationPage` | 1 | 1 | — | — |
| `Adw.BreakpointBin` | 1 | 1 | — | — |
| `Adw.ToolbarView` | 1 | 1 | — | — |
| `Gtk.Box` | 2 | 2 | — | — |
| `Adw.HeaderBar` | 1 | 1 | — | — |
| `Gtk.Stack` | 1 | 1 | — | — |
| `Adw.WindowTitle` | 1 | 1 | — | — |
| `Adw.Clamp` | 1 | 1 | — | — |
| `Gtk.Entry` (url bar) | 1 | 1 | — | `activate` |
| `Gtk.ToggleButton` | 1 | 1 | `flat` | `toggled` (port); property bind (upstream) |
| `Gtk.Button` | 3 | 3 | `flat` ×3 | `win.navigation-back/-forward/new-tab` |
| `Adw.TabBar` | 1 | 1 | — | — |
| `Gtk.ProgressBar` | 1 | 1 | `osd` | — |
| `Gtk.ActionBar` | 1 | 1 | — | — |
| `Adw.TabButton` | 1 | 1 | — | `clicked` |
| `Adw.TabView` | 1 | 1 | — | `notify::selected-page`, `page-detached` (port only) |

Repeaters: one `FindOverlay` + `WebView` pair per tab, from `new_tab(uri)`.
Actions: 16 `win.*` on both sides (`new-tab` with an `s` parameter, plus 15
parameterless).

### `lib/sidebar.rb` — the left pane
`Adw.NavigationPage` 1/1, `Adw.ToolbarView` 1/1, `Adw.HeaderBar` 1/1,
`Gtk.MenuButton` 1/1, `Gtk.Box`(`toolbar`) 1/1, `Gtk.SearchEntry` 1/1
(`search-changed`, delay 200), `Gtk.Stack`(`transition-type: none`) 1/1,
`Adw.StatusPage`(`compact`) 1/1 — the **empty state** ("No Results Found" /
"Try a different search term" / `edit-find-symbolic`).

### `lib/sidebar_menu.rb` — the primary menu
4 sections both sides: 2 `custom:` slots (`themeswitcher`, `zoom_buttons`), a
`Bookmarks` submenu of **8** items all on `win.new-tab` with a URL target, and
a final section of 2 items (`app.shortcuts`, `app.about`). Counts match.

### `lib/browse_view.rb` — the documentation tree
`Gtk.ScrolledWindow` 1/1 (`width-request: 400`), `Gtk.ListView` 1/1
(`navigation-sidebar`, `enable-rubberband: false`), `Gtk.TreeExpander` 1/1 and
`Gtk.Inscription` 1/1 per row, `Gtk.GestureClick` 1/1 (`pressed`, button 0,
middle click → `win.new-tab`). Model chain `Gio.ListStore → Gtk.TreeListModel
→ Gtk.SingleSelection(can_unselect)` on both sides. Upstream's
`BuilderListItemFactory` becomes `Gtk::SignalListItemFactory` + setup/bind —
the expected correspondence.

### `lib/search_view.rb` — fuzzy results
`Gtk.ScrolledWindow` 1/1, `Gtk.ListView` 1/1 (`navigation-sidebar`),
`Gtk.Box`/`Gtk.Inscription`/`Gtk.Button`(`pill`,`small`,`doc-tag`) 1/1 each per
row, `Gtk.GestureClick` 1/1. **19** `QUERY_TYPES` both sides. The
filter/sort model chain is replaced by Ruby (see `component-parity.md`).

### `lib/zoom_buttons.rb`
`Gtk.Box`(homogeneous) 1/1, `Gtk.Button` 2/2 (`flat`,`circular`,
`win.zoom-out`/`win.zoom-in`), `Gtk.Label` 1/1.

### `lib/find_overlay.rb`
`Gtk.Overlay` 1/1, `Gtk.Box` 4/4 (one carrying `css-name: "entry"`, built
through a `Gtk::Builder` string because `css-name` is construct-only),
`Gtk.SearchBar`(`searchbar`) 1/1, `Gtk.Image` 1/1, `Gtk.Text` 1/1,
`Gtk.Label` 1/1, `Gtk.Button` 3/3 (`linked` pair + `circular` close).
Error/empty state: `label_info` blanks and the counter resets to 0/0.

### `lib/web_view.rb`
`WebKit.WebView` 1/1, `WebKit.Settings` 3 properties 3/3, 2 user stylesheets +
1 user script 3/3, **11** stripped context-menu actions 11/11,
`decide-policy`/`context-menu`/`notify::uri`/back-forward `changed` 4/4.

### `lib/shortcuts_window.rb`
Upstream `Gtk.ShortcutsWindow` (modal, hide-on-close) / 1 `ShortcutsSection` /
**4** `ShortcutsGroup` / **26** `ShortcutsShortcut`. Port
`Adwaita::ShortcutsDialog` / 4 `ShortcutsSection` / 26 `ShortcutsItem`.
**16** accelerator bindings upstream; 17 in the port (`app.quit` folded in
from `actions.js`).

### `lib/biblioteca/application.rb`
3 app actions both sides (`quit`, `about`, stateful `color-scheme`),
`Adw.StyleManager` colour scheme applied on activate and on change, option
context description. Upstream's `Adw.Application` is `Gtk::Application` here
(bindings quirk), and `resource_base_path`, `pkg.initGettext()`,
`GLib.set_application_name` and the Flatpak guard have no counterpart.

### Not widgets, identified anyway
`lib/doc_index.rb` (8 ignored libraries, 12 section types, 9 subsection types,
4 `REQUIRED` kinds — all match), `lib/fzy.rb` (9 scoring constants, all match),
`lib/style.rb` (6 rules, byte-identical to `src/style.css`),
`lib/settings.rb` (5 keys, upstream's defaults).
