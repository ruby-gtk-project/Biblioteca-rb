# Translation parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `ced6a5b` |
| Upstream messages (distinct `(msgctxt, msgid)`) | **64** |
| Produced by the port | **64 / 64** |
| Gaps in the key set | **0** |
| Extra keys in the port | 3 (troll's three theme labels) |
| Languages upstream | **0** |
| Languages in the port | **0** |
| Domain | `org.rubygtkproject.Biblioteca` |
| Catalogue template | `po/org.rubygtkproject.Biblioteca.pot` — 64 messages |
| Gaps | **2** (both in the machinery, none in the key set) |
| Audited | 2026-11-06 |

## Round 4 — re-confirmed

Re-checked this round rather than carried forward: `po/
org.rubygtkproject.Biblioteca.pot` still has 64 real `msgid` lines (65
`^msgid "` matches including the empty header), `locale/` still does not
exist, and the one commit since the last audit (`ced6a5b`, wiring `ashpd` and
`libspelling`) touches no `lib/*.rb`, no `.blp`-equivalent widget file and no
`po/` file, so it adds no string and closes nothing here. TP-1 and TP-2 are
unchanged and still open.

## The key set is clean — every msgid survived

Re-run this round. `comm -23` over the two censuses is **empty**:

```sh
# upstream: _("…") across src/*.blp and src/*.js, plus data/app.desktop
#           Comment= and the translatable strings in data/app.metainfo.xml
# port:     msgid lines in po/org.rubygtkproject.Biblioteca.pot
comm -23 up_msgids.txt port_msgids.txt   # → empty
```

All 52 `_()` strings in `src/` plus the 12 from `data/app.desktop` and
`data/app.metainfo.xml` are produced with byte-identical msgids, including the
ones easy to retype wrong: `Switch to tabs 1⋯10` (U+22EF, not three periods),
`Move current tab at the start`, `Try a different search term`,
`Show Previous Result`, `Addition Documentation`. Nothing was reworded,
re-cased or interpolated.

The 12 extra port msgids are all accounted for: 9 come from
`data/app.metainfo.xml` and `data/app.desktop`, which upstream has but does not
list in a `po/` of its own (it has none), and 3 — `Follow system style`,
`Light style`, `Dark style` — come from troll's `ThemeSelector.blp`, which is
a submodule file and so produces no upstream rows (see
`.reports/component-identification.md` gap CI-1).

### Where the strings are marked

| Carrier | Sites | Marker | Upstream counterpart |
|---|---:|---|---|
| `data/ui/shortcuts.ui` | 30 | `translatable="yes"` | `src/Shortcuts.blp` |
| `lib/sidebar_menu.rb` | 11 | `_()` | `menu menu_app` in `src/sidebar/Sidebar.blp` |
| `data/app.metainfo.xml` | 10 | AppStream | same file |
| `lib/window.rb` | 5 | `_()` | `src/window.blp` |
| `lib/sidebar.rb` | 4 | `_()` | `src/sidebar/Sidebar.blp` |
| `lib/find_overlay.rb` | 3 | `_()` | `src/FindOverlay.blp` |
| `data/app.desktop` | 3 | `Comment=` | same file |
| `lib/theme_selector.rb` | 3 | `_()` | troll's `ThemeSelector.blp` |
| `lib/zoom_buttons.rb` | 2 | `_()` | `src/sidebar/ZoomButtons.blp` |
| `lib/about_dialog.rb` | 1 | `_()` | `src/about.js:23` |

Occurrence counts match where it matters: `Zoom in`, `Zoom out`, `Go back to
the previous page` and `Go forward to the next page` are 2 → 2 each, so the
shortcuts dialog and the widget still reach the same key.

Every translatable-string carrier in the port is listed in `po/POTFILES.in`,
and so is every `lib/*.rb` that currently has none — so a string added to any
of them is extracted without anybody editing the list.

## Languages: 0 of 0, and that is the real figure

Upstream ships **no `po/` directory**, no `LINGUAS`, no `.po` file, and calls
no `i18n` meson module. `src/biblioteca` is a wrapper that sets
`LANG=en_US.UTF-8` precisely because there is no catalogue to load. So there
are no translations to lose, and none were lost.

The port goes one step further than upstream — it marks its strings and ships
a `.pot` — and stops one step short of a working catalogue. Both gaps below
are about that step, not about any msgid.

## Gaps

| # | Gap | Evidence | Fix |
|---|---|---|---|
| TP-1 | **Nothing guards the `.pot` against drift, and it has already drifted.** `rake gettext:pot` re-ran this round regenerates the same 64 messages, but three source references move: `lib/theme_selector.rb:53-55` → `:57-59`. The committed template was generated before an edit to that file and nobody noticed, because no check compares the two | `diff` of the regenerated `.pot` against the committed one, ignoring `POT-Creation-Date`, is three `#:` lines | add `rake gettext:pot && git diff --exit-code po/` to the default task (see `.reports/test-parity.md` T-1) so a string added, moved or reworded without regenerating the template fails the build. Upstream's own `Makefile:16` has the gettext half of its lint commented out; the port should not inherit that |
| TP-2 | **The gettext wiring has never loaded a message, and cannot.** `Package.init_gettext` calls `GLib::GetText.bindtextdomain(DOMAIN, locale_dir)` and `GetText.bindtextdomain(DOMAIN, path: locale_dir)` where `locale_dir` is `lib/../locale` — **a directory that does not exist** (`ls -d locale` → `No such file or directory`). `po/` holds no `.po`, so `rake gettext:mo` compiles nothing and never creates it. Every `_()` in the port therefore returns its msgid by the untranslated path only, and the two `bindtextdomain` calls — including the libintl one that `Gtk::Builder` translates `data/ui/shortcuts.ui` through, and that GLib reads for the schema and the `.desktop` — are asserted by nothing | the drive run checks `Package::DOMAIN` and `Package.locale_dir` as *strings* (`.reports/drive.md`, `lib/package.rb` row); no check resolves a translated string | commit one real catalogue — even `po/en_GB.po` with a single deliberately different message — run `rake gettext:mo`, and add a check that `_()` returns the translated form under that locale and that the `.ui` file's titles come back translated through the builder. That is the only way either `bindtextdomain` call is ever proven to work |

Neither gap changes the headline: **64 of 64 msgids survived, byte for byte.**
What is unproven is that a catalogue, once written, would be found.
