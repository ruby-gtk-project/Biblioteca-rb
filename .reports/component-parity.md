# Component parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `7211c78` |
| Units with parity | **4 / 19** |
| Gaps | **17** |

Clean: **no.**

Parity units: `lib/style.rb`, `lib/fzy.rb`, `lib/doc_index.rb`,
`lib/documentation_page.rb` — the four that carry no user-visible string and
no widget, which is the only reason they pass the text axis.

The widget axis of this port is in genuinely good shape: every count in
`component-identification.md` matches, all 13 upstream CSS classes are
attached, the stylesheet is byte-identical, and the 16 `win.*` actions and 16
accelerators are all present. **Every gap below is on the text axis, in the
`data/` tree, or in a behaviour that no screenshot shows.**

## Gap 1 — the entire `data/` tree is missing

Upstream ships 11 files under `data/`. The port ships none, and has no `data/`
directory.

| Upstream | What the user loses |
|---|---|
| `data/app.desktop` | The app does not appear in the shell's app grid or in search. `Exec=biblioteca %U` (URL handling), `Categories`, `Keywords=GTK;libadwaita;doc;…`, `StartupNotify`, `DBusActivatable` all gone. |
| `data/app.metainfo.xml` | No AppStream entry: no summary, no 6-bullet feature list, no screenshot, no branding colours, no `display_length` requirement, no release history. The app cannot be listed by any software centre. |
| `data/app.service` | `DBusActivatable=true` has no backing `.service`, so D-Bus activation cannot work. |
| `data/icons/app.drey.Biblioteca.svg` + `.Devel.svg` + `-symbolic.svg` + `.png` + `.Source.svg` | The app has no icon anywhere — shell, alt-tab, About dialog. |
| `data/app.gschema.xml` | See Gap 6. |
| `data/screenshot.png` | Referenced by the metainfo. |

**Port: nothing. Upstream: `data/`, `data/meson.build:1`.**

## Gap 2 — the 7 bundled symbolic icons are missing

`src/icons/edit-find-symbolic.svg`, `loupe-large-symbolic.svg`,
`sidebar-show-symbolic.svg`, `tab-new-symbolic.svg`, `view-grid-symbolic.svg`,
`zoom-in-symbolic.svg`, `zoom-out-symbolic.svg` are imported into upstream's
GResource by `window.js:15-18`, `ZoomButtons.js:6-7` and `Sidebar.js:17`
precisely because they are **not** in the icon theme.

The port names all of them and ships none:

| Icon | Port site | Renders as |
|---|---|---|
| `sidebar-show-symbolic` | `lib/window.rb:313` | missing-image |
| `tab-new-symbolic` | `lib/window.rb:346` | missing-image |
| `zoom-out-symbolic` | `lib/zoom_buttons.rb:48` | missing-image |
| `zoom-in-symbolic` | `lib/zoom_buttons.rb:59` | missing-image |
| `edit-find-symbolic` | `lib/sidebar.rb:145`, `lib/find_overlay.rb:37` | missing-image |
| `view-grid-symbolic`, `loupe-large-symbolic` | used by `Adw.TabOverview` itself | missing-image |

So the sidebar toggle, the new-tab button, both zoom buttons, the find icon
and the "No Results Found" status page are all blank squares on any system
whose icon theme does not happen to carry them.

## Gap 3 — `app_id` changed, breaking the icon / desktop / D-Bus triple

`lib/biblioteca/application.rb:27` registers `org.rubygtkproject.Biblioteca`
instead of `app.drey.Biblioteca`. `lib/about_dialog.rb:50` then sets
`application_icon = @app.application_id`, so the About dialog asks for an icon
named after an id that nothing installs. Upstream's `pkg.name` is the id *and*
the icon name *and* the gschema id *and* the `.desktop`/`.service` basename, and
all four move together (`src/about.js:12`, `data/app.gschema.xml:3`).

## Gap 4 — the header bar never shows "Documentation"

Upstream binds the header title to the content page's title
(`src/window.blp:58`, `header_bar_title.title: bind content_page.title`), and
`content_page.title` starts at `_("Documentation")` (`src/window.blp:30`). So
the header reads "Documentation" from first paint until a page title arrives.

The port constructs `Adwaita::WindowTitle.new(TITLE, '')` —
`'Biblioteca'` — at `lib/window.rb:298` and only ever writes to it from
`on_title_changed` (`lib/window.rb:537`). The binding does not exist, so the
`Documentation` msgid reaches `content_page` and never reaches the header.

## Gap 5 — the default new-tab URI is a Flatpak path the port cannot reach

`lib/shortcuts_window.rb:36` hardcodes
`file:///app/share/doc/gtk4/index.html`, used by `Window::DEFAULT_URI`
(`lib/window.rb:41`), the new-tab button's action target
(`lib/window.rb:349`) and the `<Control>T` accelerator
(`lib/shortcuts_window.rb:83`).

The port does not run inside Flatpak — `lib/doc_index.rb:36-40` says so by
falling back through `/app/share/doc`, `/usr/share/doc`,
`/usr/local/share/doc`. So `DocIndex` finds the docs at `/usr/share/doc` and
every new tab opens a file under `/app` that does not exist. The default page,
the new-tab button and Ctrl+T all land on a load error. The one value that
needed the same fallback is the only one that did not get it.

## Gap 6 — the GSettings schema is not shipped

`lib/settings.rb` reimplements the 5 keys of `data/app.gschema.xml` over a JSON
file at `$XDG_CONFIG_HOME/biblioteca-rb/settings.json`. The schema itself is
not in the port, so: `gsettings`/dconf-editor cannot read or write the app's
settings, nothing migrates from an installed upstream copy, and a second
instance of the app does not see the first one's changes (upstream's
`changed::color-scheme` is cross-process; `Settings#on_changed`
(`lib/settings.rb:58`) is an in-process array of blocks).

## Gap 7 — the shortcuts dialog hides 3 accelerators it used to list

| Upstream (`src/Shortcuts.blp`) | Port (`lib/shortcuts_window.rb`) | Lost |
|---|---|---|
| `"<Control>Page_Down <Control>Tab"` (l.27) | `'<Control>Page_Down'` (l.52) | `<Control>Tab` |
| `"<Control>Page_Up <Control><Shift>Tab"` (l.32) | `'<Control>Page_Up'` (l.53) | `<Control><Shift>Tab` |
| `"<Alt>1...0"` (l.69) | `'<Alt>1'` (l.62) | the 2–0 range |

All three keys still *work* (`Adw.TabView`'s own shortcuts bind them,
`lib/window.rb:386`). The user can no longer **find** them, which is the only
job this dialog has.

## Gap 8 — the two gesture rows lost their gesture

Upstream's `shortcut-type: gesture_two_finger_swipe_right` / `_left`
(`src/Shortcuts.blp:116,121`) draws GTK's two-finger-swipe illustration. The
port renders them as items with no accelerator and an English subtitle
`'Two-finger swipe right'` / `'left'` (`lib/shortcuts_window.rb:61-62`) —
strings that exist in no msgid census on either side.

## Gap 9 — `Gtk.ShortcutsWindow` → `Adwaita::ShortcutsDialog`

Recorded as a substitution (upstream's widget is deprecated since GTK 4.18), so
not a gap on the widget axis. Two attributes do not survive it and are gaps:
upstream's `modal: true` (`src/Shortcuts.blp:4`) has no counterpart, and
upstream's section→group two-level structure is flattened to one level
(4 groups become 4 sections, `lib/shortcuts_window.rb:38-77`).

## Gap 10 — the zoom percentage goes stale

Upstream binds the **webview's** `zoom-level` straight through to the label
(`src/window.js:231`, `src/sidebar/ZoomButtons.js:10`, `SYNC_CREATE`), so any
change to the zoom level from any source updates the menu's percentage.

The port pushes the value from two call sites only — `Window#apply_zoom`
(`lib/window.rb:410`) and `Window#update_webview` (`lib/window.rb:592`). A zoom
made by WebKit itself (ctrl+scroll, pinch) changes `zoom_level` without going
through either, and the menu keeps showing the old percentage.

## Gap 11 — `ThemeSelector` was not ported, it was guessed

`lib/theme_selector.rb:9-13` says it: the `troll` submodule is not checked out,
so the widget is "reconstructed from its call site and from the shape every
GNOME app's theme switcher shares". What is actually in the port is three
`Gtk::CheckButton`s with classes `follow`/`light`/`dark` and tooltips
`'Follow System Style'` / `'Light Style'` / `'Dark Style'`.

None of those three strings appears in upstream's msgid census, and the real
widget's markup, its labels and its ~52 lines of its own CSS are unverified
against <https://github.com/sonnyp/troll>. This is the first menu item the user
sees. Nobody has compared it to the original.

## Gap 12 — `WindowState` was not ported, it was guessed

Same cause (`lib/window_state.rb:10-13`). The port saves on a single
`close-request` (`lib/window_state.rb:42`); troll's `persistWindowState`
watches the geometry properties with a debounced timeout, which is why upstream
survives a crash or a SIGTERM with the size intact and the port does not.
Unverified against the source.

## Gap 13 — the `devel` CSS class can never be applied

`lib/window.rb:267` applies `devel` when `@devel`, but `Window.new` is only
ever called as `Window.new(app, settings: settings)`
(`lib/biblioteca/application.rb:72`), so `devel:` defaults to `false` forever.
Upstream sets it from `pkg.name.endsWith(".Devel")` (`src/bin.js:24`). The
striped devel header never appears.

## Gap 14 — `GLib.set_application_name` is never called

`src/bin.js:17` sets it to `"Biblioteca"`. The port never does, so the name the
shell, the window manager and notifications read is derived from the process
name.

## Gap 15 — `resource_base_path` / `pkg.initGettext()` / the Flatpak guard

`src/application.js:11` sets `resource_base_path`, `src/main.js:4` calls
`pkg.initGettext()`, `src/bin.js:27-32` refuses to start outside Flatpak and
`src/biblioteca` forces `LANG=en_US.UTF-8`. None of the four has a counterpart.
The gettext init is the one with teeth: it is why the port cannot load a
catalogue even if one existed (see `translation-parity.md`).

## Gap 16 — the text axis, every unit

0 of 64 upstream msgids are produced by the port. Recorded per message in
`translation-parity.md`; recorded here because every unit's `Text` column is
`✗`:

| Unit | Strings upstream marks | Marked in the port |
|---|---:|---:|
| `lib/window.rb` | 4 | 0 |
| `lib/sidebar.rb` | 4 | 0 |
| `lib/sidebar_menu.rb` | 11 | 0 |
| `lib/zoom_buttons.rb` | 2 | 0 |
| `lib/find_overlay.rb` | 3 | 0 |
| `lib/shortcuts_window.rb` | 28 | 0 |
| `lib/about_dialog.rb` | 1 | 0 |

## Gap 17 — per-tab handlers are never disconnected

`Window#connect_webview` (`lib/window.rb:527`) connects four handlers per tab
and nothing disconnects them; `page-detached` (`lib/window.rb:444`) only drops
the `@overlays` entry. Upstream's equivalents are GObject bindings that die
with the tab (`src/window.js:200-233`). Each handler closes over `page` and
`view`, so a long session accumulates them.

Noting the opposite direction too, as an **unexplained extra** that should be
recorded rather than removed: the port guards `on_load_progress` and
`on_title_changed` with `view.equal?(webview)` (`lib/window.rb:558`,
`lib/window.rb:537`), which upstream does not — upstream's handler writes
`this._webview`, the *selected* view, so a background tab finishing a load
moves the foreground progress bar. The port is right and upstream is wrong;
say so rather than leaving it as an undocumented divergence.

## Axes that pass

- **Style.** All 13 upstream CSS classes are attached at the same widgets.
  `lib/style.rb`'s heredoc diffs byte-identical against `src/style.css`
  (6 rules). `css-name: "entry"` is reproduced, through a `Gtk::Builder`
  string because the property is construct-only. The one extra class,
  `theme-selector` (`lib/theme_selector.rb:48`), is libadwaita's own and
  belongs to Gap 11.
- **Behaviour.** 16 `win.*` actions, 3 app actions, 16 accelerators, both
  breakpoints and their conditions, the middle-click paths in both list views
  and in the web view, the 11 pruned context-menu actions, the find
  controller's `CASE_INSENSITIVE | WRAP_AROUND` with max 1000, the counter
  arithmetic, the zoom clamp (0.5–2.0, step 0.25), the last-tab-closes-window
  rule, the tree-path arithmetic and the scroll overshoot correction are all
  present and match.
- **Data plumbing.** `Gtk.TreeListModel` + `Gtk.SingleSelection` match.
  `SearchView`'s `Gtk.FilterListModel` + `Gtk.CustomFilter` +
  `Gtk.SortListModel` + `Gtk.CustomSorter` chain is replaced by Ruby
  filtering and sorting into a spliced `Gio::ListStore`
  (`lib/search_view.rb:221`) — a correspondence: the behaviour is located, the
  ranking order is identical, and the incremental re-filtering that is given up
  acts on a store that is built once and never mutated.

## Not checked

Steps 4 and 5 of the skill — running the port, screenshotting each unit against
the original, and driving each signal to assert its effect — have not been
done. Nothing in this ledger is backed by a running app; it is all read from
source. **Four of the gaps above (2, 5, 10, 13) are things only a run would
have caught, which is a measure of how much a run would still find.**
