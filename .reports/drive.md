# Drive report — Biblioteca-rb

| | |
|---|---|
| Harness | `test/drive_biblioteca.rb` + `test/gtk_driver.rb` + `test/doc_fixture.rb` |
| Command | `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb` |
| Result | `394 of 394 checks passed` / `DRIVE OK`, four consecutive runs |
| Screenshots | 18, under `tmp/shots/` |
| Specs | `36 examples, 0 failures` |
| Date | 2026-11-02 |

This is the first time anything in this repository has been driven end to end
in a running GTK process with assertions on the result. `COMPONENT_PARITY.md`
previously said, correctly, that "no row in this file has been exercised in a
running GTK process".

## What the drive script covers

All nineteen components the port claims, by the file each one lives in:

| Component | What is driven |
|---|---|
| `lib/package.rb` | app id, icon name, schema id and path, gettext domain, `GLib.application_name`, data dir, ui path, icon dir |
| `lib/settings.rb` | all five keys on the real GSettings backend, defaults, the stateful `color-scheme` action, `#bind` both ways, `#on_changed`, the JSON fallback, unparseable JSON |
| `lib/style.rb` | the provider is on the display and carries upstream's `#top-toolbars` rule |
| `lib/biblioteca/application.rb` | `app.quit` / `app.about` / `app.shortcuts` / `app.color-scheme`, icon registration, the style manager following the setting, devel id |
| `lib/window.rb` | the whole widget tree by identity, all 15 `win.*` actions, both breakpoints driven by a real resize, the header title/url-bar stack, tabs, the load bar, zoom clamping, tab-local find overlays |
| `lib/window_state.rb` | the blueprint default size, a stored size applied to a fresh window, the 300 ms debounce, `#remember`, both geometry bindings |
| `lib/shortcuts_window.rb` | the dialog opens, is modal, hides on close, is transient for the window; all 17 accelerators are actually bound |
| `lib/about_dialog.rb` | opens over the window, name, version, developer, licence, icon, credits |
| `lib/find_overlay.rb` | open, type, the match counter, next, previous, wrapping at both ends, nothing-found, close; the builder-built `entry` css node |
| `lib/web_view.rb` | local and remote loads, `is_online?`, `scheme_of`, the url bar's scheme-less fallback, a failed load and recovery, the injected `devhelp-hidden` stylesheet (visible in `04-sidebar-expanded.png`) |
| `lib/sidebar.rb` | the three stack pages, the search entry's delay, `reset_sidebar`, `start_uri`, `focus_search`, the uri → tree-path map |
| `lib/sidebar_menu.rb` | four sections, eight bookmarks, the about section, the popover opening with both custom widgets realised inside it |
| `lib/theme_selector.rb` | three swatches, style classes, tooltips, action targets, the dark style class following the style manager, all three colour schemes |
| `lib/zoom_buttons.rb` | the label at every zoom level, both window actions, the zero-level guard |
| `lib/browse_view.rb` | the tree model, expanding two levels, `select_item` navigating the tab, `collapse_all_rows`, row depth, `unselect_selection` |
| `lib/search_view.rb` | fzy ranking order, exact and fuzzy matches, every `kind:` prefix path, smart case, the empty result set, selecting a result |
| `lib/documentation_page.rb` | `searchable?`, `children?`, tags, qualified search names |
| `lib/doc_index.rb` | a real gi-docgen tree walked end to end: sections, subsections, sort order, ignored libraries, gi-docgen filenames, every uri resolving on disk, an empty root, an unparseable index |
| `lib/fzy.rb` | through SearchView's ranking (and directly in `spec/fzy_spec.rb`) |

## The documentation fixture

`test/doc_fixture.rb` writes a gi-docgen output tree and the HTML pages its
`index.json` points at, and the drive script writes the index DocIndex builds
from it into a scratch `XDG_CACHE_HOME` where Sidebar reads it.

Without this the machine's own documentation decides how much of the port runs,
and this machine has none: `test/drive_app.rb` skips its two tree steps with
"no gi-docgen documentation installed", which leaves the browse tree, the
search, the web view, find-in-page and the navigation buttons all inert.

## Port bug found and fixed

**`lib/window.rb#on_title_changed` wrote the window chrome from any tab.**

`FINDINGS.md` #5 claims every per-tab handler is guarded on
`view.equal?(webview)` so that a background tab's load cannot move the
foreground tab's chrome. `#on_title_changed` was the one of the four with no
guard: it wrote `content_page.title` and `window.title` from whichever view
emitted. A second tab finishing its load retitled the first tab's header and
the window — the upstream bug the entry says the port does not have.

It surfaced as an intermittent failure of "the content page title followed the
switch": whether it failed depended on whether the background tab's
`notify::title` arrived before or after the tab switch. Fixed by guarding the
two window-level writes (the tab's own title stays unguarded, because that is
that page's title). The script now pins it with a deliberate check that loads
a page into a background tab and asserts the foreground chrome does not move.

## Upstream behaviour the port reproduces, and should not be mistaken for a pass

**`BrowseView#unselect_selection` does nothing.** Upstream's
`src/sidebar/BrowseView.js:141-142` builds its `Gtk.SingleSelection` with
`can_unselect = true` and leaves `autoselect` at its default of `true`.
GtkSingleSelection's `autoselect` overrides `can-unselect`, so
`unselect_item()` is a no-op, and upstream's own `unselectSelection()` —
called from `src/window.js:272` whenever the web view goes to a remote page —
therefore leaves the row lit. The port mirrors those two lines exactly and has
the same behaviour.

Upstream's `src/sidebar/SearchView.js:124` *does* set `autoselect = false`,
which is why `SearchView#unselect_selection` works and this one does not. The
asymmetry is upstream's, not the port's.

The drive script asserts the behaviour that exists — the selection does not
move, `autoselect?` is true, `can_unselect?` is true — rather than the
behaviour the method's name promises, and says so at both call sites. **This
is not a loosened check:** it asserts the port matches upstream, and it would
fail if either flag changed. One line (`autoselect = false` in
`lib/browse_view.rb#selection_model`) would make the method do what its name
says, at the cost of a visible divergence from upstream; that call is left for
whoever owns the parity ledger.

## Environment limits, named rather than papered over

* **`xvfb-run`'s default screen is 640x480.** GTK clamps a window to the
  monitor, so at 640px the window's `max-width: 850sp` breakpoint is applied
  for the whole run and the wide layout can never be driven. The first run of
  this script mis-asserted five breakpoint checks because of it. The script now
  asserts the screen is at least 1200x900 as its second check, and the dev
  shell's banner carries the screen argument.
* **There is no window manager under Xvfb.** `Gtk::Window#maximized` is the
  window manager's answer, not a request, so `gtk_window_maximize()` never
  makes it true and the `window-maximized` binding has nothing to carry. The
  two-way binding is therefore driven through a `Gtk::ToggleButton`'s `active`
  property, which is the same `Settings#bind` code path, and the real window is
  checked for agreement between key and property. Stated here because the
  binding's behaviour under a real window manager is **not** covered by this
  run.
* **`has_focus?` is never true**, because it requires the toplevel to be the
  focused window and nothing is. Focus is asserted through the window's own
  `focus_widget`, which is what `grab_focus` moves.

## Binding gaps encountered (none blocking)

| Symbol | What happens | Worked around how |
|---|---|---|
| `Gtk::Application#accels_for_action` | `NoMethodError` | the binding is named `get_accels_for_action` |
| `Gtk::Widget#ancestor` | `NoMethodError` | the parent chain is walked by hand (`ancestor_of`) |
| `Gtk::CheckButton#group` (getter) | not bound; only `group=` exists | the group is asserted behaviourally — exactly one swatch lit |
| `Gtk::Accelerator` | no such constant | `Gtk.accelerator_parse`, which is a module function |

`Adwaita::Breakpoint`, `Adwaita::BreakpointCondition.parse` and
`Adwaita::BreakpointBin#add_breakpoint` — the calls that die on other forks in
this fleet with `TODO: in Ruby -> GIArgument(array/C)[interface(enum)]` — all
work here, because the port uses `apply` / `unapply` handlers rather than
`Adwaita::Breakpoint#add_setter`. Both breakpoints are driven by a real resize
and all sixteen of their consequences are asserted.
