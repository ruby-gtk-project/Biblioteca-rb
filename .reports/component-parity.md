# Component parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4ededb8dff1b537de09d25ce2e55d1997c43d3` (`9e4eded`) |
| Port | `ruby` @ `d63ee497e572c2d5ef7ab7790ef119be3371f9ed` (`d63ee49`) |
| Inventory | `.reports/component-identification.md` |
| Gaps | **7 open** |
| Divergences owed upstream | 1 |
| Units unverifiable from the pinned ref | 2 |
| Audited | 2026-11-02 |

The UI side of this port is in good shape. Every upstream window, dialog,
page, menu item, keyboard shortcut, preference, action, empty state and error
state was enumerated and located except the seven rows below. The four axes —
count, style, behaviour, text — hold per mapped file for every unit in
`.reports/component-identification.md`, and the text axis holds **byte for
byte**: all 64 upstream msgids are produced by the port
(`.reports/translation-parity.md`).

**Nothing below has been exercised in a running GTK process.** The `gtk4`,
`adwaita`, `webkit-gtk` and `gettext` gems are not installed in this checkout
(`ruby -e 'require "gtk4"'` → `LoadError`; `bundle exec rspec` →
`command not found: rspec`). Every "present and correct" in this report is a
claim about source text, not about pixels. A four-axis parity report on an app
nobody has started is a weaker document than it looks, and that is itself the
largest finding here.

---

## Open gaps

| # | Component | Upstream | Port | Behaviour still owed |
|---|---|---|---|---|
| 1 | Flatpak-required startup refusal | `src/bin.js:27-32` — outside Flatpak, `console.error("Flatpak required\nBiblioteca is only meant to be run sandboxed in a specific target environment.\nBypassing this will exposes users to arbitrary code breakage.")` then `exit(1)` | **absent.** `lib/package.rb:46-53` records the omission and says "Nothing replaces it" | A person who starts the app in an environment it cannot read documentation from is told so and the app stops, instead of opening an empty sidebar |
| 2 | `Gtk.UriLauncher` | `src/init.js:8` promisifies `Gtk.UriLauncher.prototype.launch` | **absent** — `grep -rn UriLauncher lib/` is empty | Nothing demonstrable: no call site for it exists anywhere on `origin/main` either, so this is dead code upstream. Recorded rather than excused: the port has no promisified launcher if a call site appears |
| 3 | Flatpak packaging | `build-aux/app.drey.Biblioteca.json`, `build-aux/app.drey.Biblioteca.Devel.json`, `build-aux/modules/{gom,jsonrpc-glib,libshumate,libspelling,sdk-docs,vte}.json` | **absent.** No `build-aux/`, no `flatpak/`, no manifest of any kind | The app can be installed the way upstream ships it. Upstream's *only* supported distribution is a Flatpak that bundles `org.gnome.Sdk.Docs` — which is where `/app/share/doc` comes from. Without it the port depends on documentation the user installed by hand |
| 4 | Theme-selector accessible labels | troll's `ThemeSelector.blp` sets an accessible label on each of the three check buttons | `lib/theme_selector.rb:197` sets `tooltip_text` only — a screen reader announces the tooltip, not a label | A screen-reader user hears "Follow system style" as a labelled control. Blocked by `FINDINGS.md` #4 (`gtk_accessible_update_property` has no usable Ruby form); the row stays a gap |
| 5 | `troll/src/widgets/ThemeSelector.{js,blp,css}` | a git submodule — a gitlink on `origin/main`, not a tree | `lib/theme_selector.rb` (204 lines) | Parity for the theme switcher — the one preference surface in the app. **It cannot be checked against the pinned ref at all.** Pin and vendor the `troll` sha, then compare |
| 6 | `troll/src/util.js` `persistWindowState` | same submodule | `lib/window_state.rb` (95 lines) | Parity for window-geometry persistence. Same cause, same remedy |
| 7 | GSettings schema reachable without an install step | upstream installs the compiled schema from `data/meson.build:52` and `src/util.js:4` opens it unconditionally | `lib/settings.rb` falls back to a per-process JSON file under `XDG_CONFIG_HOME` when no compiled schema is found, and documents the fallback as strictly worse: not cross-process, invisible to `gsettings`, and it never migrates | A colour-scheme change made in one running copy reaches the other, and `gsettings get org.rubygtkproject.Biblioteca color-scheme` shows what the app is using. Today a checkout that has not run `rake schema:compile` has neither |

## Divergences recorded, not gaps

| Component | Upstream | Port | Status |
|---|---|---|---|
| per-tab web-view handlers | `src/window.js:200-233` writes `this._webview` — the *selected* view — from the title, uri and progress handlers without checking which view emitted, so a background tab finishing a load moves the foreground tab's progress bar and briefly its title | `lib/window.rb` guards every one of those on `view.equal?(webview)` | `FINDINGS.md` #5 calls this an upstream bug. The divergence is deliberate and documented. **The upstream bug report is still owed** — until it is filed, the port is carrying a private fork of upstream's behaviour |
| gettext domain for a Devel build | `pkg.initGettext()` binds `pkg.name`, so `app.drey.Biblioteca.Devel` looks for a `.Devel` catalogue that is never built | `Package::DOMAIN` is the release id for both profiles | `FINDINGS.md` #6. Same status: a bug fix, and the upstream report is owed |
| default new-tab URI | `file:///app/share/doc/gtk4/index.html`, hardcoded in `src/window.blp:108` and `src/Shortcuts.js:11` | `Window#default_uri` → `Sidebar#start_uri` → the Gtk-4.0 node of the built index, falling back to `DocIndex::DEFAULT_ROOTS.first` | Forced by gap 3: with no Flatpak there is no `/app` |
| `doc-index.json` build step | `build-aux/build-index.js` runs under gjs at install time and writes into `pkgdatadir` (`src/meson.build:11`) | `lib/doc_index.rb` builds the same structure at first run into `XDG_CACHE_HOME/biblioteca-rb/` | Read side by side: `SECTION_TYPES`, `SUBSECTION_TYPES`, `REQUIRED`, `IGNORED_LIBRARIES`, `getLinkForDocument`, `getTagForDocument`, `getSearchNameForDocument` and the recursive sort are reproduced entry for entry |
| `Gtk.ShortcutsWindow` | used directly | kept, via `data/ui/shortcuts.ui` | `FINDINGS.md` #7: deprecated in GTK 4.18 and still the only widget with gesture rows and two-level grouping. Recorded substitution-that-wasn't |

## Correspondences, each located

These are the same thing spelled differently. Every one names a file.

| Axis row the scan flags | Where it actually is |
|---|---|
| `Gtk.BuilderListItemFactory` → nothing | `Gtk::SignalListItemFactory` with `setup`/`bind` — `lib/browse_view.rb:144`, `lib/search_view.rb:171` |
| `notify::is-online` → nothing | `on_online_changed:` callback — `lib/web_view.rb:150`, fired from `#update_is_online`; consumed at `lib/window.rb#on_webview_online` |
| `notify::webview` → nothing | `BrowseView#webview=` calls `@on_webview_changed` — `lib/browse_view.rb:72`; consumed at `lib/sidebar.rb#on_webview_changed` |
| `notify::search-term` → nothing | `SearchView#search_term=` — `lib/search_view.rb:124` |
| `search-view-selection-changed` → nothing | `on_selected:` callback — `lib/search_view.rb:98`, consumed at `lib/sidebar.rb#on_search_selection` |
| `Gtk.ListScrollFlags.NONE` → nothing | the symbol `:none` — `lib/browse_view.rb:187`, `lib/search_view.rb:131` |
| `WebKit.ContextMenuAction` ×11, `UserStyleLevel`, `UserScriptInjectionTime`, `UserContentInjectedFrames`, `PolicyDecisionType`, `NavigationType` → nothing | Ruby symbols: `UNDESIRED_CONTEXT_MENU_ACTIONS` (11 entries), `:user`, `:end`, `:all_frames`, `:navigation_action` — `lib/web_view.rb:45-57, 215-240` |
| `WebKit.Settings` → nothing | `view.settings.tap` — `lib/web_view.rb:159` |
| `Gtk.License.GPL_3_0_ONLY` → nothing | `:gpl_3_0_only` — `lib/about_dialog.rb:51` |
| `Gtk.StackPage` ×2 → `Gtk::Stack` | `header_bar_stack.add_named(window_title, 'title')` / `add_named(url_bar_clamp, 'url_bar')` — `lib/window.rb:140` |
| `Adw.Breakpoint#add_setters` → nothing | `apply`/`unapply` handlers — `lib/window.rb#apply_narrow_window`, `#apply_narrow_content` |
| `app.about` / `app.shortcuts` / `win.new-tab` ×8 absent from `lib/sidebar.rb` | `lib/sidebar_menu.rb:40-44, 72` — the targets are interpolated, so the scan cannot see them |
| five `bind_property` / `bind_property_full` calls | `lib/window.rb#connect_webview`'s five `notify::` handlers, plus `#on_title_changed` reproducing the `from_value ? [true, …] : [false, null]` empty-title guard |
| `Gtk.CustomFilter` / `FilterListModel` / `CustomSorter` / `SortListModel` | `lib/search_view.rb#rank` + `#refresh_results` (one `splice`). `FINDINGS.md` #1 is why |

## Axis checks that passed in full

* **CSS classes.** The 14 classes upstream applies — `main-window`, `flat`,
  `osd`, `devel`, `searchbar`, `linked`, `circular`, `navigation-sidebar`,
  `doc-tag`, `pill`, `small`, `compact`, `toolbar`, `theme-selector` — are all
  applied in the port, and the rules behind `#top-toolbars`, `.searchbar` and
  `button.pill.small` are `src/style.css` copied verbatim into
  `lib/style.rb`'s `CSS` heredoc (diffed).
* **Actions.** 16 `win.*` + 4 app-level (`quit`, `about`, `color-scheme`,
  `shortcuts`), matching upstream exactly.
* **Keyboard shortcuts.** 17 `set_accels_for_action` calls; 24 accelerator
  strings in the dialog, byte-identical to `src/Shortcuts.blp` after XML
  escaping (diffed); 2 gesture rows kept with their `shortcut-type`.
* **Installed data.** `data/app.desktop`, `data/app.gschema.xml`,
  `data/app.service` and `data/app.metainfo.xml` are upstream's files with only
  the app id substituted — `diff` after normalising the id is empty for all
  four. 7 symbolic icons + 3 application icons present.
* **Empty / error states.** The one empty state upstream has — the
  `Adw.StatusPage` reading "No Results Found" / "Try a different search term",
  `compact` — is at `lib/sidebar.rb#status_page` and wired at
  `lib/sidebar.rb#on_search`. The find bar's "no matches" state (clearing
  `label_info`) is at `lib/find_overlay.rb#on_not_found`. The offline/online
  header swap is at `lib/window.rb#on_webview_online`. The one error state
  **not** ported is gap 1.
