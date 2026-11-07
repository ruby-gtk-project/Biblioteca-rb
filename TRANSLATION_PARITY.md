# Translation parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` |
| Source of the gap list | `.reports/translation-parity.md` (audited at `7211c78`) |
| Upstream messages (distinct) | 61 |
| Produced by the port | **61 / 61** |
| Extra keys in the port | 3 (troll's, see below) |
| Languages upstream | 0 |
| Languages in the port | 1 (`fr`, complete: 64 / 64 messages) |
| Domain | `org.rubygtkproject.Biblioteca` |
| Template | `po/org.rubygtkproject.Biblioteca.pot` — 64 messages |

Upstream ships no `po/` directory and no translations: `src/biblioteca` forces
`LANG=en_US.UTF-8` with the comment *"We do not support translations"*. There
is therefore no donated catalogue to carry across. What this round owed was the
extraction half — marking every string so that a catalogue becomes possible —
and that is what landed.

## The domain

`Package::DOMAIN` is `org.rubygtkproject.Biblioteca`, the port's application
id. That is upstream's derivation: `pkg.initGettext()` binds `pkg.name`, and
`data/app.gschema.xml`'s `gettext-domain` and `data/app.metainfo.xml`'s
`<translation type="gettext">` are both `@app_id@`. The port's id differs from
upstream's so that the two do not collide on the session bus, and the domain
follows the id, as it does upstream.

The domain is the *release* id for both profiles, where upstream's would be the
Devel id for a Devel build. That is a divergence, and it is a bug fix:
`FINDINGS.md` #6.

## Where the strings are marked

| Carrier | Messages | Marker |
|---|---:|---|
| `data/ui/shortcuts.ui` | 30 | `translatable="yes"` |
| `lib/sidebar_menu.rb` | 11 | `_()` |
| `lib/window.rb` | 5 | `_()` |
| `lib/sidebar.rb` | 4 | `_()` |
| `lib/find_overlay.rb` | 3 | `_()` |
| `lib/theme_selector.rb` | 3 | `_()` (troll's) |
| `lib/zoom_buttons.rb` | 2 | `_()` |
| `lib/about_dialog.rb` | 1 | `_()` |
| `data/app.metainfo.xml` | 9 | AppStream |
| `data/app.desktop` | 1 | `Comment=` |

`_()` reaches a class through `include Package::Translatable`, which calls
`GetText.bindtextdomain_to(base, …)`. `GetText.included` extends as well as
includes, so `_()` resolves both in a class body — which is where
`SidebarMenu::BOOKMARKS`, `ThemeSelector::CHOICES` and
`Window::DOCUMENTATION_TITLE` need it — and in instance methods.

`data/ui/shortcuts.ui` is translated by GtkBuilder, through libintl, which is
why `Package.init_gettext` binds `GLib::GetText.bindtextdomain` as well as the
Ruby gem's. `data/app.desktop` and `data/app.metainfo.xml` are translated by
GLib and AppStream, through the same `.mo`.

## The three extra keys

`Follow system style`, `Light style`, `Dark style`. These are not inventions:
they are troll's own msgids, read out of
`troll/src/widgets/ThemeSelector.blp`, where upstream adds the widget from
(`src/sidebar/Sidebar.js:82`). They are absent from a census of
`github.com/workbenchdev/Biblioteca` only because troll is a submodule and the
census does not follow it.

The six strings `.reports/translation-parity.md` flagged as existing in no
upstream census are gone:

| String | What happened |
|---|---|
| `Keyboard Shortcuts` (the dialog's own title) | dropped — `GtkShortcutsWindow` supplies it. The identically-spelled menu item is upstream's, `src/sidebar/Sidebar.blp:111` |
| `Two-finger swipe right` | dropped — the row is `shortcut-type: gesture_two_finger_swipe_right` again |
| `Two-finger swipe left` | dropped — likewise |
| `Follow System Style` | replaced by troll's `Follow system style` |
| `Light Style` | replaced by troll's `Light style` |
| `Dark Style` | replaced by troll's `Dark style` |

## The template

`po/POTFILES.in` lists the three data files and every file under `lib/`,
including the ones with no strings, so that a string added to one of them is
extracted without anybody editing the list. `po/extract.rb` builds
`po/org.rubygtkproject.Biblioteca.pot` from it and handles the four formats the
port marks strings in: `_()` in Ruby, `translatable="yes"` in the `.ui`, the
desktop keys, and `<summary>`/`<caption>`/`<p>`/`<li>` in the metainfo.
`rake gettext:pot` regenerates it; `rake gettext:mo` compiles any `po/*.po`
into `locale/<lang>/LC_MESSAGES/`, which is the path `Package.locale_dir`
points at.

`rxgettext` from the `gettext` gem would cover the Ruby files and none of the
other three formats, which is why `po/extract.rb` exists rather than a
`GetText::Tools::Task`.

## Verified how

```
$ ruby po/extract.rb
64 messages written to po/org.rubygtkproject.Biblioteca.pot
```

and the template's keys compared against a census of upstream's `_("…")` calls
plus `data/app.desktop` and `data/app.metainfo.xml`: 61 of 61 present, 0
missing, 3 extra (troll's).

Updated this round — both are now closed:

**TP-2.** `po/fr.po` is a real, complete French catalogue: all 64 messages
`po/org.rubygtkproject.Biblioteca.pot` carries, translated, not a stub with a
handful filled in. `spec/translation_spec.rb` compiles it with
`GetText::Tools::MsgFmt` into `locale/fr/LC_MESSAGES/` (the exact path
`Package.locale_dir` resolves to), sets `Locale.current = "fr"`, and asserts
that a class built the same way every real `lib/*.rb` class is —
`include Package::Translatable`, then `_('Main Menu')` — returns
`"Menu principal"`, not the msgid; a second expectation pins the documented
fallback-to-msgid behaviour for a locale with no catalogue (`"xx"`). Both pass
under `rspec` (see TEST_PARITY.md). The lookup path — `Package.locale_dir` →
`<lang>/LC_MESSAGES/org.rubygtkproject.Biblioteca.mo` → a translated string
back from `_()` — is now exercised, not assumed.

**TP-1.** `rake gettext:check_pot_drift` (`rakelib/biblioteca.rake`) runs
`rake gettext:pot` and then `git diff --exit-code -- po/`, exactly what this
row originally asked for, and is wired into `rake default`
(`rakelib/default.rake`) and the CI workflow
(`.github/workflows/ci.yml`). Running it for the first time found real drift —
two `#:` location comments in `lib/theme_selector.rb` had moved — regenerated
and committed in this round's commit.

## Still owed

1. `po/LINGUAS`, once there is more than one `.po`.
2. A second language, so `po/LINGUAS` has something to list.
