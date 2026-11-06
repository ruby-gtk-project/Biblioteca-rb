# Component parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `ced6a5b` |
| Inventory | `.reports/component-identification.md` |
| Runtime gate | `drive_ok=true`, **394 of 394 checks**, 19 components, re-run this round |
| Gaps | **7 open** |
| Divergences recorded, not gaps | 5 |
| Units unverifiable against upstream | 2 |
| Audited | 2026-11-06 |

**What changed since the last round.** The previous edition of this file said
"Nothing below has been exercised in a running GTK process", and that was true
when it was written. It is no longer: `test/drive_biblioteca.rb` was re-run
this round under `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24'`
and reported `394 of 394 checks passed / DRIVE OK`, the two older drivers still
pass (`test/drive_app.rb` 31 steps / 2 skipped, `test/drive_sidebar.rb` 24
steps / 0 failures), and `spec/` reports 36 examples / 0 failures. Every
"present and correct" below is now a claim about a running process except
where a row says otherwise — and three rows say otherwise.

The UI side of the port holds on all four axes. Every upstream window, dialog,
page, menu item, keyboard shortcut, preference, action, empty state and error
state was enumerated and located except the gaps below. The text axis holds
byte for byte: all 64 upstream msgids are produced
(`.reports/translation-parity.md`).

## Round 4 — independently re-verified, one wiring commit since the last audit

Re-run from a clean invocation this round, not copied from the previous
report: `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby
test/drive_biblioteca.rb` → `394 of 394 checks passed` / `DRIVE OK`;
`test/drive_app.rb` → `31 steps, 2 skipped, 0 failures`; `test/drive_sidebar.rb`
→ `24 steps, 0 failures`; the RSpec invocation the dev shell banner prints →
`36 examples, 0 failures`; `rubocop lib exe spec test po` → `32 files
inspected, no offenses detected`. The runtime gate holds at `ced6a5b`, same as
the committed `drive_ok=true` figure for this round (394 checks, 0 failed, 18
components reported by the harness — one lower than the 19 this report
counts because the harness's component tally and this report's component
tally are not drawn from the same list; see
`.reports/component-identification.md` for the 19).

One commit landed between the last audit and this one
(`ced6a5b`, "Wire in ashpd and libspelling"). It adds two gem dependencies and
flake wiring; it adds no widget, no signal, no action and no translatable
string, so nothing above moves. `FINDINGS.md` #10, added by that commit,
documents that neither gem has a call site on `origin/main` — confirmed by
`grep -rn 'UriLauncher\|Xdp\|Spelling\|libspelling' $(git ls-tree -r
--name-only origin/main)` returning only the one `Xdp.Portal` line in
`src/bin.js` that `lib/package.rb` already declines to replicate (gap 1,
below) and the `libspelling.json` Flatpak module entry, which is packaging,
not a GI import. **This is not a new component and not a new gap** — wiring
an unused gem is neither — but the commit message and `FINDINGS.md` #10 frame
the *existing*, still-open gap 1 (the missing Flatpak-refusal guard) as a
"documented design decision from before this round". `.reports/
accountability-ensurance.md` F-6 (new this round) covers why that framing is
itself a finding, independent of gap 1 staying open on this ledger.

No other change in `ced6a5b` touches a row below; the 7 open gaps, the 5
divergences and the 2 unverifiable units carry forward unchanged from the
previous round and were re-confirmed by re-reading each cited line at
`ced6a5b` rather than assumed stable.

---

## Open gaps

| # | Component | Upstream | Port | Behaviour still owed |
|---|---|---|---|---|
| 1 | **Flatpak-required startup refusal** — the app's one error state | `src/bin.js:27-32`: outside Flatpak, `console.error("Flatpak required\nBiblioteca is only meant to be run sandboxed in a specific target environment.\nBypassing this will exposes users to arbitrary code breakage.")` then `exit(1)` | **absent.** `lib/package.rb:46-53` records the omission and says "Nothing replaces it" | A person who starts the app somewhere it cannot read documentation from is told so and the app stops, instead of opening on an empty sidebar. The port *has* the information to say it — `DocIndex.default_root` is `nil` and `DocIndex#docs` is `[]` — and says nothing |
| 2 | **Flatpak packaging** | `build-aux/app.drey.Biblioteca.json`, `…Devel.json`, `build-aux/modules/{gom,jsonrpc-glib,libshumate,libspelling,sdk-docs,vte}.json` | **absent.** No `build-aux/`, no manifest of any kind | The app installs the one way upstream ships it. Upstream's Flatpak bundles `org.gnome.Sdk.Docs`, which *is* `/app/share/doc`; without it the port depends on documentation the user installed by hand. This gap also causes test-parity gaps 3, 6 and 7 |
| 3 | **`troll` submodule cannot be diffed** — `ThemeSelector` | a gitlink on `origin/main`; `troll/src/widgets/ThemeSelector.{js,blp,css}` | `lib/theme_selector.rb` (243 lines) | Parity for the theme switcher — the app's only preference surface — *checked against its source*. Today the port's own comments are the only description of what troll does, which is not a check. Fix: pin and vendor the troll sha under `vendor/troll/` |
| 4 | **`troll` submodule cannot be diffed** — `persistWindowState` | same submodule, `troll/src/util.js` | `lib/window_state.rb` (95 lines) | Same cause, same fix. The 300 ms debounce, the two `Gio.SettingsBindFlags.DEFAULT` binds and the `if (width && height)` guard are asserted by the drive run against the port's *description* of troll, not against troll |
| 5 | **Theme-swatch accessible labels are unverifiable** | troll's `ThemeSelector.blp` sets `accessibility { label: … }` on each of the three check buttons | `lib/theme_selector.rb#labelled_button` sets it through a `Gtk::Builder` `<accessibility>` block — the only route Ruby has | **Proven this round:** there is no Ruby getter (`Gtk::CheckButton` exposes `accessible_id`, `accessible_parent`, `accessible_role` and nothing else), **and `Gtk::Builder` accepts `<property name="no-such-prop">` inside `<accessibility>` without raising or warning.** So the one accessibility claim in the port is set by a mechanism that fails silently and that no check can read back. `grep -n accessible test/*.rb` is empty. Fix: assert the property name in `BUTTON_UI` against GTK's accessible-property list in the drive script, and verify the label once out of band over AT-SPI |
| 6 | **`Sidebar#start_index` clamps away upstream's "no selection"** | `src/sidebar/Sidebar.js:30` and `:62` set `selection_model.selected = doc_index.start_index` directly. With documentation installed but no `Gtk-4.0`, `start_index` is `-1`, which GTK reads as `GTK_INVALID_LIST_POSITION` — **nothing is selected and nothing is loaded** | `lib/sidebar.rb#start_index` turns a negative index into `0`, so the first namespace alphabetically is selected *and its page is loaded into the tab* | Either upstream's behaviour, or a recorded divergence with a reason. It is neither: the clamp is undocumented in `FINDINGS.md`, in `PORTING.md` and in every report, and no check exercises it — `test/drive_biblioteca.rb:404` covers `start_index == -1` only with an **empty** `docs` array, where the clamp cannot be observed |
| 7 | **GSettings reachable without an install step** | `data/meson.build:46` installs the compiled schema; `src/util.js:4` opens it unconditionally | `lib/settings.rb` falls back to a per-process JSON file under `XDG_CONFIG_HOME` when no compiled schema is found, and documents the fallback as strictly worse: not cross-process, invisible to `gsettings`, never migrated | A colour-scheme change in one running copy reaches the other, and `gsettings get org.rubygtkproject.Biblioteca color-scheme` shows what the app is using. A checkout that has not run `rake schema:compile` has neither. The drive run exercises **both** backends, so the fallback is tested — it is still a behaviour gap, not a test gap |

## Divergences recorded, not gaps

| Component | Upstream | Port | Status |
|---|---|---|---|
| per-tab web-view handlers | `src/window.js:200-233` writes `this._webview` — the *selected* view — from the title, uri and progress handlers without checking which view emitted, so a background tab finishing a load moves the foreground tab's progress bar and briefly its title | `lib/window.rb` guards all five on `view.equal?(webview)` | `FINDINGS.md` #5. Deliberate; the drive run pins it with a deliberate background-tab check. **The upstream bug report is still owed** |
| gettext domain for a Devel build | `pkg.initGettext()` binds `pkg.name`, so `app.drey.Biblioteca.Devel` looks for a `.Devel` catalogue nothing builds | `Package::DOMAIN` is the release id for both profiles | `FINDINGS.md` #6. Same status; report owed |
| default new-tab URI | `file:///app/share/doc/gtk4/index.html`, hardcoded at `src/window.blp:108` and `src/Shortcuts.js:11` | `Window#default_uri` → `Sidebar#start_uri` → the `Gtk-4.0` node of the built index, falling back to `DocIndex::DEFAULT_ROOTS.first` | Forced by gap 2: with no Flatpak there is no `/app` |
| `doc-index.json` build step | `build-aux/build-index.js` runs under gjs at install time into `pkgdatadir` (`src/meson.build:11`) | `lib/doc_index.rb` builds the same structure on first run into `XDG_CACHE_HOME/biblioteca-rb/` | Diffed entry for entry this round: `SECTION_TYPES` (12), `SUBSECTION_TYPES` (7), `REQUIRED` (4), `IGNORED_LIBRARIES` (8), `getLinkForDocument` (19 cases), `getTagForDocument` (7 relabels + default), `getSearchNameForDocument` (4 groups) and the recursive name sort all match |
| `Gtk.ShortcutsWindow` | used directly | kept, via `data/ui/shortcuts.ui` | `FINDINGS.md` #7: deprecated in GTK 4.18 and still the only widget with gesture rows and two-level grouping |

## Correspondences, each located

The scan flags these as missing; each is the same thing spelled differently.

| Axis row the scan flags | Where it actually is |
|---|---|
| `Gtk.ShortcutsWindow` / `ShortcutsSection` / `ShortcutsGroup` / `ShortcutsShortcut` | `data/ui/shortcuts.ui`, which is not under `lib/` — 27 objects, 30 translatable titles, 24 accelerators, 2 gesture rows |
| `app.about` / `app.quit` / `app.shortcuts` | `lib/sidebar_menu.rb#ABOUT_SECTION`, `lib/shortcuts_window.rb#accels` — the scan's action regex does not match a hash value |
| `Gtk.BuilderListItemFactory` | `Gtk::SignalListItemFactory` with `setup`/`bind` — `lib/browse_view.rb#list_factory`, `lib/search_view.rb#list_factory` |
| `notify::is-online` | `on_online_changed:` callback — `lib/web_view.rb#update_is_online` → `lib/window.rb#on_webview_online` |
| `notify::webview` | `BrowseView#webview=` calls `@on_webview_changed` → `lib/sidebar.rb#on_webview_changed` |
| `notify::search-term` | `SearchView#search_term=` |
| `search-view-selection-changed` | `on_selected:` callback → `lib/sidebar.rb#on_search_selection` |
| `Gtk.ListScrollFlags.NONE` | the symbol `:none` |
| `WebKit.ContextMenuAction` ×11, `UserStyleLevel`, `UserScriptInjectionTime`, `UserContentInjectedFrames`, `PolicyDecisionType` | Ruby symbols in `lib/web_view.rb` |
| `Gtk.License.GPL_3_0_ONLY` | `:gpl_3_0_only` — `lib/about_dialog.rb` |
| `Gtk.StackPage` ×2 | `header_bar_stack.add_named(window_title, 'title')` / `add_named(url_bar_clamp, 'url_bar')` |
| `Adw.Breakpoint#add_setters` | `apply`/`unapply` handlers — `lib/window.rb#apply_narrow_window`, `#apply_narrow_content`; both breakpoints driven by a real resize in the drive run, all 16 consequences asserted |
| five `bind_property` / `bind_property_full` calls | `lib/window.rb#connect_webview`'s five `notify::` handlers, with `#on_title_changed` reproducing the empty-title `[false, null]` guard |
| `Gtk.CustomFilter` / `FilterListModel` / `CustomSorter` / `SortListModel` | `lib/search_view.rb#rank` + one `#refresh_results` splice. `FINDINGS.md` #1 is why |
| `Gtk.UriLauncher` promisified at `src/init.js:8` | nowhere. Dead code upstream: `grep -rn UriLauncher` over `origin/main` finds only that one line and no call site. Recorded, not owed |

## Axis checks that passed in full

* **CSS classes.** All 14 upstream classes — `main-window`, `flat`, `osd`,
  `devel`, `searchbar`, `linked`, `circular`, `navigation-sidebar`, `doc-tag`,
  `pill`, `small`, `compact`, `toolbar`, `theme-selector` — are applied, and
  `comm` over the two css streams shows nothing upstream-only. `src/style.css`
  is copied verbatim into `lib/style.rb`. The drive run confirms the provider
  is on the display and carries the `#top-toolbars` rule.
* **Actions.** 16 `win.*` + 4 app-level (`quit`, `about`, `color-scheme`,
  `shortcuts`). All 20 activated in the drive run.
* **Keyboard shortcuts.** 17 `set_accels_for_action` calls, all 17 asserted
  bound at runtime; 24 accelerator strings in the dialog, byte-identical to
  `src/Shortcuts.blp` after XML escaping; 2 gesture rows kept. The 12 tab
  accelerators the dialog lists and `#accels` does not bind come from
  `Adwaita::TabViewShortcuts::ALL_SHORTCUTS`, as upstream's do.
* **Main menu, verified against the live model this round.** 4 sections; both
  custom ids (`themeswitcher`, `zoom_buttons`) present; 8 bookmark items each
  carrying `action="win.new-tab"` and its own `target`, labels and URLs
  identical to `Sidebar.blp`; the about section's two items pointing at
  `app.shortcuts` and `app.about`.
* **Installed data.** `data/app.desktop`, `app.gschema.xml`, `app.service` and
  `app.metainfo.xml` are upstream's with only the app id substituted. 7
  symbolic icons + 3 application icons present, and `rake schema:validate`
  runs `glib-compile-schemas --strict --dry-run` clean.
* **Empty / error states.** The `Adw.StatusPage` ("No Results Found" / "Try a
  different search term", `compact`) at `lib/sidebar.rb#status_page`, wired at
  `#on_search`; the find bar's blank counter at
  `lib/find_overlay.rb#on_not_found`; the offline/online header swap at
  `lib/window.rb#on_webview_online` — all three driven. The one error state
  **not** ported is gap 1.
* **One upstream behaviour faithfully reproduced, and it looks like a bug.**
  `BrowseView#unselect_selection` does nothing, because upstream's
  `Gtk.SingleSelection` leaves `autoselect` at `true`, which overrides
  `can-unselect`. The port mirrors both lines. The drive run asserts the
  behaviour that exists rather than the one the method name promises, and
  flags it at both call sites. Correct as parity; still worth an upstream
  issue.
