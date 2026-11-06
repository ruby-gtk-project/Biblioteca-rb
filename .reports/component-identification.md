# Component identification — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `ced6a5b` |
| Upstream units | 13 (11 widget classes + the application class + the standalone shortcuts definition) |
| Port units | 19 `lib/*.rb` + `data/ui/shortcuts.ui` |
| Units identifiable from the pinned ref | 11 of 13 |
| **Units that cannot be identified at all** | **2** — see Gap CI-1 |
| Scans | `scripts/component-scan.sh` on `src/` and on `lib/` |
| Audited | 2026-11-06 |

Upstream is a GJS app with a declarative half, so Step 1 of the skill applies:
the seven `.blp` files and the one `menu` block in them *are* the inventory,
and the `.js` beside each one carries the callbacks. Rows from the two halves
are unioned per port file before anything is compared.

**Round 4.** Re-run against `ced6a5b`, the one commit since the last audit.
`git show ced6a5b --stat` touches `FINDINGS.md`, the gemspec, the flake and
the lockfiles only — no `lib/*.rb`, no `data/ui/*`, no upstream file — so the
unit map, the 19 port units and the "2 units unidentifiable" figure (CI-1,
the `troll` submodule) are unchanged and re-confirmed rather than re-derived.

## Unit map

One upstream unit (`.blp` + `.js`, or the submodule file) → one port file.

| # | Unit | Upstream files | Port file |
|---:|---|---|---|
| 1 | Application | `src/application.js`, `src/actions.js`, `src/main.js`, `src/init.js`, `src/bin.js` | `lib/biblioteca/application.rb`, `lib/package.rb` |
| 2 | About dialog | `src/about.js` | `lib/about_dialog.rb` |
| 3 | Stylesheet | `src/style.css` | `lib/style.rb` |
| 4 | Settings | `data/app.gschema.xml`, `src/util.js` | `lib/settings.rb` |
| 5 | Window | `src/window.blp` + `src/window.js` | `lib/window.rb` |
| 6 | Window geometry | `troll/src/util.js` `persistWindowState` | `lib/window_state.rb` |
| 7 | Shortcuts (dialog + every accel) | `src/Shortcuts.blp` + `src/Shortcuts.js` | `lib/shortcuts_window.rb` + `data/ui/shortcuts.ui` |
| 8 | Find overlay | `src/FindOverlay.blp` + `src/FindOverlay.js` | `lib/find_overlay.rb` |
| 9 | Web view | `src/WebView.blp` + `src/WebView.js` | `lib/web_view.rb` |
| 10 | Sidebar | `src/sidebar/Sidebar.blp` + `Sidebar.js` | `lib/sidebar.rb` |
| 11 | Main menu (`menu menu_app`) | the `menu` block in `Sidebar.blp` | `lib/sidebar_menu.rb` |
| 12 | Theme selector | `troll/src/widgets/ThemeSelector.{js,blp,css}` | `lib/theme_selector.rb` |
| 13 | Zoom row | `src/sidebar/ZoomButtons.blp` + `ZoomButtons.js` | `lib/zoom_buttons.rb` |
| 14 | Browse tree | `src/sidebar/BrowseView.blp` + `BrowseView.js` | `lib/browse_view.rb` |
| 15 | Search results | `src/sidebar/SearchView.blp` + `SearchView.js` | `lib/search_view.rb` |
| 16 | Tree node | `src/sidebar/DocumentationPage.js` | `lib/documentation_page.rb` |
| 17 | Index builder | `build-aux/build-index.js` | `lib/doc_index.rb` |
| 18 | Fuzzy matcher | `src/sidebar/fzy.js` | `lib/fzy.rb` |

No port file is without an upstream counterpart. No upstream `.blp`/`.js` pair
is without a port file.

## Scan totals

| Stream | Upstream `src/` | Port `lib/` |
|---|---:|---:|
| widget rows / instances | 55 / 92 | 55 / 71 |
| `type` rows | 28 | 34 |
| controller rows | 2 | 2 |
| css rows | 16 | 17 |
| action rows | 21 | 17 |
| signal rows | 32 | 46 |

The widget-instance gap (92 → 71) is the shortcuts dialog: upstream's 26
`ShortcutsShortcut` + 4 `ShortcutsGroup` + 1 `ShortcutsSection` + 1
`ShortcutsWindow` are in `src/Shortcuts.blp`, and in the port they are in
`data/ui/shortcuts.ui`, which is not under `lib/`. `comm` on the widget
streams shows exactly those four types as the only upstream types absent from
`lib/` — all four are present in `data/ui/shortcuts.ui` (27 `<object>`
declarations, 30 `translatable="yes"` titles, 24 accelerator strings).

The three `action` rows the scan calls missing (`app.about`, `app.quit`,
`app.shortcuts`) are real and literal in `lib/sidebar_menu.rb` and
`lib/shortcuts_window.rb`; the scan's action regex does not match a hash value.
The four `signal` rows it calls missing (`notify::is-online`,
`notify::search-term`, `notify::webview`, `search-view-selection-changed`) are
the four GObject properties/signals the port replaces with Ruby callbacks —
located one by one in `.reports/component-parity.md`.

## Per-unit inventories

### `src/window.blp` + `src/window.js` → `lib/window.rb` — the application window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `main-window`, `devel` (dev build only) | — | 360×360 request, 1080×768 default |
| `Adw.Breakpoint` | 2 | — | `apply`, `unapply` | `max-width: 850sp`, `max-width: 450sp` |
| `Adw.TabOverview` | 1 | — | `create-tab` | `enable-new-tab: true` |
| `Adw.OverlaySplitView` | 1 | — | `notify::show-sidebar` | `show-sidebar` ↔ `button_sidebar.active` |
| `Adw.NavigationPage` | 1 | — | `notify::title` | title starts at `_("Documentation")` |
| `Adw.BreakpointBin` | 1 | — | — | 360×360 request |
| `Adw.ToolbarView` | 1 | — | — | top bar + bottom bar + content |
| `Gtk.Box` | 2 | — | — | `#top-toolbars` (named, styled), `box_navigation` (spacing 6, halign start) |
| `Adw.HeaderBar` | 1 | — | — | — |
| `Gtk.Stack` | 1 | — | — | pages `title` / `url_bar` |
| `Adw.WindowTitle` | 1 | — | — | follows `content_page.title` |
| `Adw.Clamp` | 1 | — | — | holds the URL bar |
| `Gtk.Entry` | 1 | — | `activate` | `input-purpose: url`, hexpand |
| `Gtk.ToggleButton` | 1 | `flat` | `toggled` | `sidebar-show-symbolic`, hidden until narrow |
| `Gtk.Button` | 3 | `flat` ×3 | `win.navigation-back`, `win.navigation-forward`, `win.new-tab` | back / forward / new tab |
| `Adw.TabBar` | 1 | — | — | bound to the tab view |
| `Gtk.ProgressBar` | 1 | `osd` | — | load progress |
| `Gtk.ActionBar` | 1 | — | — | hidden until narrow |
| `Adw.TabButton` | 1 | — | `clicked` | halign end, hidden until narrow |
| `Adw.TabView` | 1 | — | `notify::selected-page`, `page-detached` | `shortcuts: ALL_SHORTCUTS` |

Repeaters: one `Adw.TabPage` + `FindOverlay` + `WebView` per tab, driven by
`win.new-tab`. Conditional: `bottom_toolbar`, `tab_button`, `sidebar_button`
visible only under a breakpoint; `tab_bar` and `button_new_tab` hidden under
the narrow-content breakpoint; `box_navigation` is *reparented* between the
header bar and the bottom bar.

Actions installed: 16 on the `win` group — `new-tab` (`s`), `close-tab`,
`navigation-forward`, `navigation-back`, `zoom-in`, `zoom-out`, `reset-zoom`,
`global-search`, `focus-urlbar`, `toggle-sidebar`, `toggle-overview`,
`update-buttons`, `find`, `find-prev`, `find-next`, `close-find`.

### `src/sidebar/Sidebar.blp` + `Sidebar.js` → `lib/sidebar.rb` — the left pane

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.NavigationPage` | 1 | — | — | title "Biblioteca", untranslated upstream |
| `Adw.ToolbarView` | 1 | — | — | two top bars |
| `Adw.HeaderBar` | 1 | — | — | — |
| `Gtk.MenuButton` | 1 | — | — | `open-menu-symbolic`, `primary: true`, tooltip `_("Main Menu")` |
| `Gtk.Box` | 1 | `toolbar` | — | holds the search entry |
| `Gtk.SearchEntry` | 1 | — | `search-changed` | `search-delay: 200`, placeholder `_("Search Biblioteca")` |
| `Gtk.Stack` | 1 | — | — | `transition-type: none`; 3 pages |
| `Adw.StatusPage` | 1 | `compact` | — | **the app's only empty state**: `_("No Results Found")` / `_("Try a different search term")` / `edit-find-symbolic` |

### `menu menu_app` → `lib/sidebar_menu.rb` — the main menu

Four sections, in order: `custom: "themeswitcher"` → `custom: "zoom_buttons"`
→ a `_("Bookmarks")` submenu of 8 items → `_("Keyboard Shortcuts")` +
`_("About Biblioteca")`. 11 menu items, 2 custom slots (each a component
boundary filled by `popover.add_child(widget, id)`). Verified against the live
`Gio::Menu` this round: 4 sections, 8 bookmark items each carrying
`action="win.new-tab"` and its own `target`, both custom ids present.

### `src/FindOverlay.blp` + `FindOverlay.js` → `lib/find_overlay.rb`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Overlay` | 1 | — | — | child is the web view |
| `Gtk.Box` | 4 | `linked` (nav box only) | — | toolbar (margins 12/24, valign start, halign end), content (spacing 6), the `css-name: entry` box (220 wide), nav |
| `Gtk.SearchBar` | 1 | `searchbar` | — | `connect_entry(search_text)` |
| `Gtk.Image` | 1 | — | — | `edit-find-symbolic` |
| `Gtk.Text` | 1 | — | `notify::text` | 10 chars / 10 max |
| `Gtk.Label` | 1 | — | — | match counter, `xalign: 1`, `opacity: 0.5`; **its own empty state** is the blank label |
| `Gtk.Button` | 3 | `circular` (close only) | `win.find-prev`, `win.find-next`, `win.close-find` | — |

### `src/sidebar/BrowseView.blp` + `BrowseView.js` → `lib/browse_view.rb`

`Gtk.ScrolledWindow` (vexpand, 400 wide) › `Gtk.ListView`
(`navigation-sidebar`, `enable-rubberband: false`, `activate`) with a row
template of `Gtk.TreeExpander` › `Gtk.Inscription` (hexpand, valign center,
`nat-chars: 10`, `ellipsize_end`). One `Gtk.GestureClick` (`button: 0`,
`pressed`) — middle click opens the row in a new tab. Repeater: one row per
`DocumentationPage` in a `Gtk.TreeListModel` over nested `Gio.ListStore`s.

### `src/sidebar/SearchView.blp` + `SearchView.js` → `lib/search_view.rb`

Same scroller/list-view shell; row template is `Gtk.Box` › `Gtk.Inscription`
(`nat-chars: 25`) + `Gtk.Button` (`pill`, `small`, `doc-tag`, insensitive —
the symbol-kind pill). One `Gtk.GestureClick` (`button: 0`). Repeater: one row
per ranked result.

### `src/sidebar/ZoomButtons.blp` → `lib/zoom_buttons.rb`

`Gtk.Box` (homogeneous) › `Gtk.Button` `zoom-out-symbolic` (`flat`,
`circular`, `win.zoom-out`, tooltip `_("Zoom out")`) + `Gtk.Label` "100%" +
`Gtk.Button` `zoom-in-symbolic` (`flat`, `circular`, `win.zoom-in`, tooltip
`_("Zoom in")`).

### `src/Shortcuts.blp` → `data/ui/shortcuts.ui`

`Gtk.ShortcutsWindow` (`modal`, `hide-on-close`) › 1 `ShortcutsSection` › 4
`ShortcutsGroup` (`_("Tabs")` 12, `_("Navigation")` 9, `_("Zoom")` 3,
`_("General")` 2) › 26 `ShortcutsShortcut`, 2 of them gesture rows
(`gesture_two_finger_swipe_left/right`). Counted in the port's `.ui`: 30
translatable titles, 24 accelerator strings, 2 gesture rows.

### `src/WebView.blp` + `WebView.js` → `lib/web_view.rb`

`WebKit.WebView` (vexpand) with a `WebKit.Settings` carrying three flags; two
`WebKit.UserStyleSheet`s and one `WebKit.UserScript` (all `ALL_FRAMES`,
`USER` / injection `END`); 11 pruned `WebKit.ContextMenuAction`s; signals
`notify::uri`, `decide-policy`, `context-menu`, and `changed` on the
back/forward list.

### Application unit → `lib/biblioteca/application.rb` + `lib/package.rb`

Actions: `app.quit`, `app.about`, `app.color-scheme` (stateful, from the
settings), `app.shortcuts` (installed by the shortcuts unit). Option-context
description. Style manager follows `color-scheme`. **One error state**:
upstream's `src/bin.js:27-32` refuses to start outside Flatpak — see
`.reports/component-parity.md` gap 1.

## Stylesheet side

`src/style.css` defines 4 rule groups: `#top-toolbars` (dark + light media
queries), `.searchbar > * > *`, `.searchbar`, `button.pill.small`. All four are
in `lib/style.rb`'s heredoc verbatim. `.doc-tag` is **applied and never
defined** — dead on both sides, carried deliberately.

troll's `ThemeSelector.css` is the fifth stylesheet; it lives in
`lib/theme_selector.rb` and cannot be diffed (Gap CI-1).

## Gaps

| # | Gap | Fix |
|---|---|---|
| CI-1 | **Two units cannot be identified from any ref in this repository.** `troll` is a gitlink on `origin/main` (`.gitmodules` → `https://github.com/sonnyp/troll.git`) and the submodule is not checked out. `troll/src/widgets/ThemeSelector.{js,blp,css}` and `troll/src/util.js` `persistWindowState` therefore produce **no upstream rows at all**: the inventories above for units 6 and 12 are reconstructed from the port's own comments, which is the wrong direction. The skill names this case explicitly ("Widgets from a submodule or a vendored library… If the submodule is not checked out the scan cannot see it"). | Pin the troll sha, vendor the three `ThemeSelector.*` files and `util.js` under `vendor/troll/` on the `ruby` branch, scan them, and union the rows into `lib/theme_selector.rb` and `lib/window_state.rb` before the next parity round |
