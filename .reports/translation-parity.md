# Translation parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4ededb8dff1b537de09d25ce2e55d1997c43d3` (`9e4eded`) |
| Port | `ruby` @ `d63ee497e572c2d5ef7ab7790ef119be3371f9ed` (`d63ee49`) |
| Upstream messages (distinct `(msgctxt, msgid)`) | **64** |
| Produced by the port | **64 / 64** |
| Gaps in the key set | **0** |
| Extra keys in the port | 3 |
| Upstream occurrences | 69 call sites |
| Port occurrences | 72 call sites |
| Languages upstream | **0** |
| Languages in the port | **0** |
| Domain | `org.rubygtkproject.Biblioteca` |
| `domain_source` | `data/app.gschema.xml` `gettext-domain` + `data/app.metainfo.xml` `<translation type="gettext">`, both the app id — upstream's `pkg.initGettext()` derivation |
| Catalogue template | `po/org.rubygtkproject.Biblioteca.pot` — 64 messages |
| Audited | 2026-11-02 |

## The headline: the key set is clean

`comm -23` over the two censuses is **empty**. All 64 messages upstream marks
are produced by the port with byte-identical msgids — including the ones that
are easy to retype wrong: `Switch to tabs 1⋯10` (U+22EF, not three periods),
`Move current tab at the start`, `Addition Documentation`,
`Try a different search term`, `Show Previous Result`. Nothing was reworded,
nothing was re-cased, nothing was interpolated. That is the thing this skill
exists to check and the port passes it.

Per-message occurrence counts also match where it matters: `Zoom in`,
`Zoom out`, `Go back to the previous page` and `Go forward to the next page`
are each 2 → 2, so the shortcuts dialog and the widget both still reach the
same key.

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

## Languages: 0 of 0, and that is the real parity figure

Upstream ships **no `po/` directory**, no `LINGUAS`, no `.po` files, and calls
no `i18n` meson module. `src/biblioteca:5` says it outright:

> `# We do not support translations but the AboutWindow is translated by default`
> `# force app in English see .../pull/40#issuecomment-1811380922`
> `LANG=en_US.UTF-8`

There is no donated catalogue to inherit and none to destroy. Language parity
is 0 / 0 and met. The port goes further than upstream — it ships a `po/`
directory, a `POTFILES.in`, an extractor and a 64-message `.pot` — and that is
additive work, not parity work.

The port is also right not to force `LANG`. Upstream forces English because
`Adw.AboutDialog` would otherwise show translated chrome around untranslated
app strings; the port marks its strings, so the reason is gone.

## Gaps

| # | Gap | Where | What is owed |
|---|---|---|---|
| 1 | One marked string in `data/app.metainfo.xml` never reaches the catalogue: `<developer><name>Akshay Warrier</name></developer>`. AppStream treats `<name>` as translatable; `po/extract.rb`'s `METAINFO_STANDALONE` matches only `<summary>` and `<caption>`, and `METAINFO_PARAGRAPH` only `<p>`/`<li>` under `<description>` | `po/extract.rb:71-73` | Either extract it, or state in `po/extract.rb` that it is excluded and why. The census finds it in the source and not in the `.pot`; a reader cannot currently tell whether that is a decision or an oversight |
| 2 | The port has 67 source keys and a 64-message `.pot`, and nothing checks the two against each other | `rakelib/biblioteca.rake` `gettext:pot` | A check that fails when `po/*.pot` and the source census disagree. Gap 1 is invisible today precisely because nothing compares them |
| 3 | `rake gettext:mo` globs `po/*.po` and there are none, so it is a no-op that exits 0 | `rakelib/biblioteca.rake:155-170` | Nothing for parity — upstream ships 0 languages too. Recorded because a task that silently does nothing reads as a task that worked |

## Extra keys in the port

| Key | Where | Status |
|---|---|---|
| `Follow system style` | `lib/theme_selector.rb:53` | troll's `ThemeSelector.blp`. **Not** invented by the port |
| `Light style` | `lib/theme_selector.rb:54` | same |
| `Dark style` | `lib/theme_selector.rb:55` | same |

These three are the reason the port's key set is 67 and not 64. They are
upstream's strings, from `troll/src/widgets/ThemeSelector.blp` — but `troll` is
a **git submodule**, a gitlink on `origin/main` rather than a tree, so the
census of the upstream side cannot see them and reports them as extras. They
are almost certainly byte-identical to troll's (the port's comment says the
file was ported from it), and **that cannot be confirmed from the pinned ref.**
Confirming it means pinning troll's sha and censusing that tree too; until then
three of the port's 67 msgids are unverified, and a reworded one here would
look exactly like this.

## Occurrence counts, read as a finding and not a pass condition

69 upstream call sites over 64 keys; 72 port call sites over 67 keys. The
3-site difference is the three troll keys, one site each. Every shared key has
the same number of call sites on both sides, so there is no "the key is present
but one of its five buttons lost it" case hiding behind a clean key diff —
which is the failure this column exists to catch.

## Numbers, so they reconcile

```
msgid-census.sh up    -> 69 rows,  cut -f1,2 | sort -u -> 64 keys
msgid-census.sh port  -> 136 rows, of which 64 are the .pot itself
                      -> 72 source rows, sort -u       -> 67 keys
comm -23 up.keys port.keys -> 0      (no upstream message missing)
comm -13 up.keys port.keys -> 3      (the troll strings)
comm -12 up.keys port.keys -> 64     (ported)
ls up/po/*.po  -> no such directory  -> 0 languages, 0 translated strings
ls port/po/*.po -> none              -> 0 languages, 0 translated strings
```

Note the census's two false positives, which appear identically on **both**
sides and so cancel in the diff: `Biblioteca` (`Name=`) and
`GTK;libadwaita;doc;documentation;api;manual;devhelp;` (`Keywords=`) in
`data/app.desktop`. Both carry upstream's `# TRANSLATORS: Don't translate`
comment, which the scanner does not read, and `po/extract.rb`'s
`DESKTOP_KEYS = %w[Comment]` correctly excludes them. Not gaps.
