# Biblioteca — upstream component inventory

Upstream: `origin/main`, a **GJS** (GNOME JavaScript) app using GTK 4,
libadwaita 1 and WebKitGTK 6.0. UI is declared in **blueprint** (`.blp`)
files compiled into a GResource by `gjspack`, with one `.js` file per `.blp`
holding the callbacks and the `GObject.registerClass` wiring. Per the
`component-identification` skill, the component is the *set* of files, so each
row below unions the `.blp` tree with its `.js` behaviour.

What the app is: a documentation browser. A sidebar holds a tree of GNOME
platform docs plus a fuzzy search over a flattened index; the content side is
a tab view of WebKit webviews with navigation, zoom, find-in-page and a URL
bar that appears only for online pages.

The `ruby` branch today has **3** `.rb` files — `lib/biblioteca.rb`,
`lib/biblioteca/application.rb` (a blank Adwaita window with a "not written
yet" status page) and `lib/biblioteca/rb/version.rb`. **Nothing user-facing is
ported.** Target paths follow the pilot port (`gnome-contacts-rb`): flat
`lib/<thing>.rb`, one upstream unit per file, with `lib/biblioteca/application.rb`
kept as the gem entry point.

## Units

### `src/window.blp` + `src/window.js` → `lib/window.rb`
The main window: tab overview over a split view, sidebar on one side, toolbar
view with headerbar/tab bar/progress bar on the other. **present: no**

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` (template root) | 1 | `main-window`, `devel` (dynamic, `__DEV__` only) | — | 1080×768 default, 360×360 min; title bound to `"<page title> - Biblioteca"` |
| `Adw.Breakpoint` `window_breakpoint` | 1 | — | — | `max-width: 850sp` → `split_view.collapsed`, `button_sidebar.visible`; adds runtime setters for `browse_view`/`search_view` `width-request: 300` |
| `Adw.TabOverview` `tab_overview` | 1 | — | `create-tab` → `newTab()` | `enable-new-tab`, view = `tab_view` |
| `Adw.OverlaySplitView` `split_view` | 1 | — | — | `show-sidebar` ↔ `button_sidebar.active` (two-way bind) |
| `Adw.NavigationPage` `content_page` | 1 | — | — | title `_("Documentation")`, rebound to the webview title |
| `Adw.BreakpointBin` | 1 | — | — | 360×360 min |
| `Adw.Breakpoint` `toolbar_breakpoint` | 1 | — | `apply` → `#moveNavigationDown`, `unapply` → `#moveNavigationUp` | `max-width: 450sp` → show `bottom_toolbar`/`tab_button`, hide `button_new_tab`/`tab_bar`. Reparents `box_navigation` between headerbar and action bar |
| `Adw.ToolbarView` | 1 | — | — | — |
| `Gtk.Box` (`name: top-toolbars`) | 1 | styled by `#top-toolbars` in `style.css` | — | vertical; holds headerbar + tab bar + load bar |
| `Adw.HeaderBar` `content_header_bar` | 1 | — | — | title widget is `header_bar_stack` |
| `Gtk.Stack` `header_bar_stack` | 1 | — | — | 2 pages: `title`, `url_bar`; switched by `#onWebViewOnline` |
| `Adw.WindowTitle` `header_bar_title` | 1 | — | — | title bound to `content_page.title` |
| `Adw.Clamp` | 1 | — | — | wraps the URL entry |
| `Gtk.Entry` `url_bar` | 1 | — | `activate` → `#onActivateURLBar` | `input-purpose: url`; buffer text bound to `webview.uri`; missing scheme gets `http://` prefixed |
| `Gtk.ToggleButton` `button_sidebar` | 1 | `flat` | — | icon `sidebar-show-symbolic`, tooltip `_("Open Sidebar")`, hidden until the breakpoint |
| `Gtk.Box` `box_navigation` | 1 | — | — | spacing 6; reparented by the toolbar breakpoint |
| `Gtk.Button` `button_back` | 1 | `flat` | `win.navigation-back` | `go-previous-symbolic`, `_("Back")`; sensitivity from `can_go_back()` |
| `Gtk.Button` `button_forward` | 1 | `flat` | `win.navigation-forward` | `go-next-symbolic`, `_("Forward")`; sensitivity from `can_go_forward()` |
| `Gtk.Button` `button_new_tab` | 1 | `flat` | `win.new-tab` with target `"file:///app/share/doc/gtk4/index.html"` | `tab-new-symbolic`, `_("New Tab")` |
| `Adw.TabBar` `tab_bar` | 1 | — | — | view = `tab_view` |
| `Gtk.ProgressBar` `load_bar` | 1 | `osd` | — | fraction from `estimated-load-progress`; reset to 0 after 500 ms at 1.0 |
| `Gtk.ActionBar` `bottom_toolbar` | 1 | — | — | hidden until the toolbar breakpoint |
| `Adw.TabButton` `tab_button` | 1 | — | `clicked` → toggle `tab_overview.open` | view = `tab_view` |
| `Adw.TabView` `tab_view` | 1 | — | `notify::selected-page` → `#updateWebView` | `shortcuts: all_shortcuts`; each page holds a `FindOverlay` wrapping a `WebView` |

Repeaters: `tab_view` pages — one `FindOverlay`+`WebView` pair per tab, created
by `newTab(uri)`. Conditional: `devel` CSS class under `__DEV__`; URL bar page
shown only when the webview scheme is http/https.

**17 `win.` actions** installed on a `Gio.SimpleActionGroup`: `new-tab` (param
`s`), `close-tab`, `navigation-forward`, `navigation-back`, `zoom-in`,
`zoom-out`, `reset-zoom`, `global-search`, `focus-urlbar`, `toggle-sidebar`,
`toggle-overview`, `update-buttons`, `find`, `find-prev`, `find-next`,
`close-find`. Zoom clamps to 0.5–2.0 in 0.25 steps. `close-tab` on the last
tab closes the window.

### `src/sidebar/Sidebar.blp` + `src/sidebar/Sidebar.js` → `lib/sidebar.rb`
The sidebar navigation page: menu button, search entry, and a stack of
browse view / search view / empty state. **present: no**

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.NavigationPage` (template root) | 1 | — | — | title "Biblioteca" |
| `Adw.ToolbarView` | 1 | — | — | — |
| `Adw.HeaderBar` | 1 | — | — | — |
| `Gtk.MenuButton` `button_menu` | 1 | — | menu model `menu_app` | `open-menu-symbolic`, `_("Main Menu")`, `primary: true`; popover gets two `custom:` children added in code |
| `Gtk.Box` | 1 | `toolbar` | — | holds the search entry |
| `Gtk.SearchEntry` `search_entry` | 1 | — | `search-changed` → `#onSearch` | `search-delay: 200`, `_("Search Biblioteca")` |
| `Gtk.Stack` `stack` | 1 | — | — | `transition-type: none`; children: `status_page`, `browse_view`, `search_view` |
| `Adw.StatusPage` `status_page` | 1 | `compact` | — | **empty state**: `_("No Results Found")` / `_("Try a different search term")` / `edit-find-symbolic` |

Loads `doc-index.json` from `pkgdatadir`, builds a `Gio.ListStore` tree of
`DocumentationPage`s plus a flattened store for search, and keeps a
`uri_to_tree_path` map so the sidebar selection follows the webview URI.
`resetSidebar()` collapses all rows and selects `start_index`.

### `menu menu_app` (in `src/sidebar/Sidebar.blp`) → `lib/sidebar_menu.rb`
The primary menu — a standalone blueprint object with no backing class.
**present: no**

- Section 1: `custom: "themeswitcher"` → hosts troll's `ThemeSelector`
- Section 2: `custom: "zoom_buttons"` → hosts `ZoomButtons`
- Section 3: submenu `_("Bookmarks")`, **8 items**, all `win.new-tab` with a
  URL target: Developer Documentation, Human Interface Guidelines, JavaScript,
  Vala, Rust, Python, Blueprint, DevDocs
- Section 4: `_("Keyboard Shortcuts")` → `app.shortcuts`,
  `_("About Biblioteca")` → `app.about`

### `src/sidebar/BrowseView.blp` + `src/sidebar/BrowseView.js` → `lib/browse_view.rb`
The documentation tree. **present: no**

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` (template root) | 1 | — | — | `width-request: 400` (300 when collapsed) |
| `Gtk.ListView` `browse_list_view` | 1 | `navigation-sidebar` | `activate` → toggle row expansion | `enable-rubberband: false` |
| `Gtk.TreeExpander` `expander` (list item factory) | per row | — | — | `list-row` bound to the tree row |
| `Gtk.Inscription` (list item factory) | per row | — | — | `nat-chars: 10`, `ellipsize_end`, text ← `DocumentationPage.name` |
| `Gtk.GestureClick` (controller) | 1 | — | `pressed` → `#onGestureClick` | button 0; **middle click** opens the row's URI via `win.new-tab` |

Models: `Gtk.TreeListModel` over the root `Gio.ListStore`, wrapped in a
`Gtk.SingleSelection` with `can_unselect`. `selection-changed` loads the URI
into the current webview unless it is already there. Property `webview`
(`notify::uri` → `#syncSelection`). `selectItem(path)` scrolls with a
one-row overshoot and `#adjustScrolling` corrects the edge cases;
`ITEM_HEIGHT = 38` is the hardcoded row height the middle-click hit test uses.

### `src/sidebar/SearchView.blp` + `src/sidebar/SearchView.js` → `lib/search_view.rb`
Fuzzy search results over the flattened doc index. **present: no**

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.ScrolledWindow` (template root) | 1 | — | `notify::search-term` → `#onNotifySearchTem` | `width-request: 400` |
| `Gtk.ListView` `search_list_view` | 1 | `navigation-sidebar` | — | `enable-rubberband: false` |
| `Gtk.Box` (list item factory) | per row | — | — | — |
| `Gtk.Inscription` (list item factory) | per row | — | — | `nat-chars: 25`, text ← `search_name` |
| `Gtk.Button` (list item factory) | per row | `pill`, `small`, `doc-tag` | — | insensitive tag badge, label ← `tag` |
| `Gtk.GestureClick` (controller) | 1 | — | `pressed` → `#onGestureClick` | middle click → `win.new-tab`, suppressing the selection side effect |

Models: `Gtk.FilterListModel` + `Gtk.CustomFilter` → `Gtk.SortListModel` +
`Gtk.CustomSorter` (descending fzy score) → `Gtk.SingleSelection`
(`autoselect: false`, `can_unselect`). Emits its own signal
`search-view-selection-changed(string uri)`. Query syntax: a leading
`<type>:` prefix filters by tag, matched against **19 QUERY_TYPES**
(additional, alias, bitfield, callback, class, constant, constructor, enum,
error, function, interface, namespace, macro, method, property, signal,
struct, union, vfunc). Search is case-sensitive only when the needle contains
an uppercase letter.

### `src/sidebar/fzy.js` → `lib/fzy.rb`
The fzy fuzzy matcher (`hasMatch`, `score`), MIT, vendored from
jhawthorn/fzy.js. Not user-facing on its own but the search ranking is
meaningless without it. **present: no**

### `src/sidebar/DocumentationPage.js` → `lib/documentation_page.rb`
The model object behind both list views: a `GObject.Object` with properties
`name`, `tag`, `search_name`, `score`, `uri`, `children` (`Gio.ListStore`).
**present: no**

### `src/sidebar/ZoomButtons.blp` + `src/sidebar/ZoomButtons.js` → `lib/zoom_buttons.rb`
The zoom control embedded in the primary menu popover. **present: no**

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Box` (template root) | 1 | — | — | `homogeneous` |
| `Gtk.Button` `button_zoom_out` | 1 | `flat`, `circular` | `win.zoom-out` | `zoom-out-symbolic`, `_("Zoom out")` |
| `Gtk.Label` `label_zoom` | 1 | — | — | shows `"<zoom×100>%"`, bound from `zoom-level` |
| `Gtk.Button` `button_zoom_in` | 1 | `flat`, `circular` | `win.zoom-in` | `zoom-in-symbolic`, `_("Zoom in")` |

Property: `zoom-level` (double, default 1).

### `src/WebView.blp` + `src/WebView.js` → `lib/web_view.rb`
One documentation webview. **present: no**

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `WebKit.WebView` (template root) | 1 | — | `notify::uri` → `#updateIsOnline`; `decide-policy` → `#onDecidePolicy`; `context-menu` → `#onContextMenu` | `vexpand` |
| `WebKit.Settings` (type, not a widget) | 1 | — | — | back/forward gestures on, developer extras off, smooth scrolling on |

Property `is-online` (true for http/https schemes; drives the headerbar
stack). Injects a user stylesheet hiding `.devhelp-hidden`, plus an
overshoot-shadow user script and its stylesheet (`.overshoot-overlay-top`,
`.overshoot-overlay-bottom`, with a dark-scheme variant). Middle-clicking a
link ignores the decision and fires `win.new-tab` with the URI.
`get_back_forward_list()` `changed` → `win.update-buttons`. Strips **11
undesired context-menu actions**: STOP, RELOAD, OPEN_LINK_IN_NEW_WINDOW,
DOWNLOAD_LINK_TO_DISK, OPEN_IMAGE_IN_NEW_WINDOW, DOWNLOAD_IMAGE_TO_DISK,
OPEN_FRAME_IN_NEW_WINDOW, OPEN_VIDEO_IN_NEW_WINDOW, OPEN_AUDIO_IN_NEW_WINDOW,
DOWNLOAD_VIDEO_TO_DISK, DOWNLOAD_AUDIO_TO_DISK.

### `src/FindOverlay.blp` + `src/FindOverlay.js` → `lib/find_overlay.rb`
Find-in-page, an overlay floating over the webview. **present: no**

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Overlay` (template root) | 1 | — | — | child is the `WebView` |
| `Gtk.Box` `find_toolbar` | 1 | — | — | `valign: start`, `halign: end`, margins 12/24 |
| `Gtk.SearchBar` `search_bar` | 1 | `searchbar` (shadow + 12px radius in `style.css`) | — | `connect_entry(search_text)` |
| `Gtk.Box` | 3 | — | — | outer (spacing 6), entry-shaped (`css-name: "entry"`, 220 wide), button pair |
| `Gtk.Image` | 1 | — | — | `edit-find-symbolic` |
| `Gtk.Text` `search_text` | 1 | — | `notify::text` → `find` | 10 chars wide |
| `Gtk.Label` `label_info` | 1 | — | — | `"<n> of <total>"`, opacity 0.5, right-aligned; blank when no matches |
| `Gtk.Button` `button_previous` | 1 | (inside `linked` box) | `win.find-prev` | `go-up-symbolic`, `_("Show Previous Result")` |
| `Gtk.Button` `button_next` | 1 | (inside `linked` box) | `win.find-next` | `go-down-symbolic`, `_("Show Next Result")` |
| `Gtk.Button` `close_find_button` | 1 | `circular` | `win.close-find` | `window-close-symbolic`, `_("Close Search")` |

`WebKit.FindController`: `found-text` / `failed-to-find-text` keep the match
counter; searches are `CASE_INSENSITIVE | WRAP_AROUND`, max 1000 matches.
**Error/empty state**: `label_info` goes blank and the counter resets to 0/0.

### `src/Shortcuts.blp` + `src/Shortcuts.js` → `lib/shortcuts_window.rb`
The keyboard shortcuts window, a standalone blueprint object. **present: no**

`Gtk.ShortcutsWindow` (`hide-on-close`, `modal`), one `ShortcutsSection`, **4
`ShortcutsGroup`s, 28 `ShortcutsShortcut`s**:
- `_("Tabs")` — 12: open/close tab, next/prev tab, first/last tab, view all
  open tabs, move tab backward/forward/to start/to end, switch to tabs 1⋯10
- `_("Navigation")` — 9: back, forward, focus global search, find in page,
  find next, find previous, focus URL bar, plus two **gesture** entries
  (`gesture_two_finger_swipe_right`/`_left`)
- `_("Zoom")` — 3: zoom in, zoom out, reset zoom
- `_("General")` — 2: show sidebar (`F9`), shortcuts (`<Control>question`)

`Shortcuts.js` also installs the `app.shortcuts` action and registers **16
accelerator bindings** (`win.new-tab('…gtk4/index.html')` `<Control>T`,
`win.close-tab` `<Control>W`, `win.navigation-forward` `<Alt>Right`,
`win.navigation-back` `<Alt>Left`, `win.zoom-in` `<Control>plus`/`equal`,
`win.zoom-out` `<Control>minus`/`underscore`, `win.reset-zoom` `<Control>0`,
`win.global-search` `<Control>K`, `win.focus-urlbar` `<Control>L`,
`win.toggle-sidebar` `F9`, `win.toggle-overview` `<Shift><Control>O`,
`win.find` `<Control>F`, `win.find-prev` `<Shift><Control>G`, `win.find-next`
`<Control>G`, `win.close-find` `Escape`).

### `src/about.js` → `lib/about_dialog.rb`
`Adw.AboutDialog` — name, developer "Akshay Warrier", copyright "© 2024",
GPL-3.0-only, website biblioteca.sonny.re, issue URL `/feedback`, 2
developers, 1 artist (Jakub Steiner), and an `add_credit_section(_("Contributors"))`
with 2 names. **present: no**

### `src/application.js` + `src/actions.js` + `src/main.js` + `src/init.js` + `src/bin.js` → `lib/main.rb`
The application unit. **present: partially** — `lib/biblioteca/application.rb`
is a placeholder window; none of the actions or the color scheme exist.

- `Adw.Application`, id from `pkg.name`, `resource_base_path /app/drey/Biblioteca`
- `activate` creates the window once, applies the colour scheme, calls
  `window.open()` (present + focus global search + reset sidebar on first map)
- Option context description `<https://biblioteca.sonny.re>`
- **3 app actions**: `app.quit` (`<Control>Q`), `app.about`, and the stateful
  `app.color-scheme` from `settings.create_action`
- `Adw.StyleManager` colour scheme applied from the `color-scheme` setting and
  re-applied on `changed::color-scheme`
- `bin.js` refuses to run outside Flatpak and sets `__DEV__` from the app id
  suffix — **not portable** (see Blockers)

### `troll/src/widgets/ThemeSelector.js` → `lib/theme_selector.rb`
Vendored from the `troll` submodule (not checked out in this clone, so it
produces no scan rows): the follow-system / light / dark selector shown as the
first `custom:` item in the primary menu, three `Gtk.CheckButton`s driving
`app.color-scheme`. **present: no**

### `troll/src/util.js` (`persistWindowState`) → `lib/window_state.rb`
Saves and restores window width/height/maximized/fullscreened through
GSettings. **present: no**

### `data/app.gschema.xml` → `lib/settings.rb`
**5 keys**: `color-scheme` (i, 0), `window-width` (i, 0), `window-height`
(i, 0), `window-maximized` (b, false), `window-fullscreened` (b, false).
**present: no**. The pilot port backs the same keys with a JSON file under
`XDG_CONFIG_HOME` rather than requiring a compiled schema; do the same here.

### `src/style.css` → `lib/style.rb` (or a `data/style.css` loaded by a provider)
**6 rules**: `#top-toolbars` background in dark and light schemes, the
`.searchbar > * > *` 12px radius, the `.searchbar` shadow, and
`button.pill.small` for the search tag badges. Classes applied in the
blueprints and defined here: `searchbar`, `pill`+`small`. `main-window`,
`doc-tag`, `devel`, `compact`, `osd`, `flat`, `circular`, `linked`,
`navigation-sidebar`, `toolbar` come from libadwaita's stylesheet.
**present: no**

### `build-aux/build-index.js` → `lib/doc_index.rb`
Not a widget, but the sidebar is empty without it: walks the installed
GI-DocGen HTML trees and writes the `doc-index.json` that `Sidebar` loads
(tree of name/tag/search_name/uri/children plus `start_index`), skipping **8
deprecated libraries** and classifying symbols into **12 section types** and
**9 subsection types**. **present: no**

## Blockers

- **WebKitGTK 6.0 bindings.** Every content pane is a `WebKit.WebView`, and
  there is no `webkit` gem in the ruby-gnome family. The sibling
  `webkit-gtk-rb` checkout in this project tree is the only lead; until a
  binding exists (gir_ffi / a hand-rolled GObject-Introspection shim), the
  webview, the find controller, the context-menu filtering, the user
  script/stylesheet injection, the back/forward list and the zoom level have
  no Ruby equivalent. This is the single largest risk in the port.
- **`Gtk.BuilderListItemFactory` with blueprint templates.** Both list views
  declare their row templates inline in `.blp`, including
  `bind template.item as <$DocumentationPage>.name`. The house style has no
  `.ui` files, so these become `Gtk::SignalListItemFactory` with bind/unbind
  handlers — a faithful rebuild, not a transcription.
- **Flatpak-only runtime.** `bin.js` hard-exits outside Flatpak, and the
  default page is `file:///app/share/doc/gtk4/index.html`, i.e. the Flatpak
  SDK docs mounted at `/app`. A checkout-run Ruby port has no `/app`, so the
  default URI and the doc index root have to be configurable.
- **`doc-index.json` generation.** `build-index.js` is a meson install script
  that reads the SDK docs tree at install time. Outside Flatpak there is no
  such tree, so the port needs either a bundled index or a path option.
- **`troll` submodule not checked out.** `ThemeSelector` and
  `persistWindowState` are read from upstream's imports and from knowledge of
  troll, not from source in this clone. Verify against
  <https://github.com/sonnyp/troll> before porting those two.
- **No `po/` catalogue upstream.** The blueprints and JS use `_()` throughout
  (around 40 distinct msgids) but there is no `po/` directory on
  `origin/main`, so there is nothing to port for `translation-parity` beyond
  keeping the msgids marked.
