# Translation parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `7211c78` |
| Upstream messages (distinct keys) | **64** |
| Upstream occurrences (call sites) | 69 |
| Produced by the port | **0** |
| Gaps | **64** |
| Extra keys in the port | 0 (it produces none) |
| Languages upstream | 0 |
| Languages in the port | 0 |
| Domain | `app.drey.Biblioteca` (`<schemalist gettext-domain="@app_id@">`, `<translation type="gettext">@app_id@</translation>`) — unconfirmed against an installed `.mo`, because no `po/` exists to build one |

Clean: **no. 0 of 64.**

## The two halves, separately

**The language half is trivially met.** Upstream has no `po/` directory
(`git ls-tree origin/main` has no `po` entry; the `Makefile`'s msgfmt check is
commented out at `Makefile:15-16`), and `src/biblioteca` — the launcher script
— forces `LANG=en_US.UTF-8` with the comment *"We do not support translations
but the AboutWindow is translated by default"*. 0 languages, 0 translated
strings. The port destroys nothing, because there is nothing yet to destroy.

**The key-set half fails completely.** Upstream marks 64 distinct messages with
`_()` across its blueprints and JS, plus its `.desktop` and AppStream metainfo.
The port marks **zero**:

```
$ .claude/skills/translation-parity/scripts/msgid-census.sh <port> | wc -l
0
```

No `gettext` require, no `_()`, `n_()`, `N_()`, `C_()` anywhere in `lib/` or
`exe/`, no `po/`, no `POTFILES.in`, and no `pkg.initGettext()` equivalent
(upstream: `src/main.js:4`). Every user-visible string in the port is a bare
Ruby literal.

This matters even with upstream at zero languages, for two reasons the skill
names. First, the moment anyone runs `xgettext` over the port it extracts
nothing, so the port cannot be the side that *starts* the catalogue — and
upstream's own metainfo already declares `<translation type="gettext">`, i.e.
upstream intends to be translated and has simply not been. Second, 54 of the
64 strings are in the port *as the right bytes already*; the work left is a
marker, not a retype, and leaving it undone now is what guarantees a later
reworder silently forks the key.

## Census diff

**54 upstream msgids are present in the port as unmarked literals.** Each is
two things at once: the upstream key is missing (no marker produces it) and the
string shows in English only. Per the skill these are `gap`, not `ported`.

The port column is the **first textual occurrence** of those bytes in `lib/`
or `exe/`, which for a handful of rows is the class comment rather than the
label; the marker is owed at every site, which `component-parity.md` Gap 16
counts per unit.

| # | msgid | Upstream site | First occurrence in the port |
|---|---|---|---|
| 1 | `About Biblioteca` | `src/sidebar/Sidebar.blp:116` | `lib/about_dialog.rb:7` |
| 2 | `Akshay Warrier` | `data/app.metainfo.xml` | `lib/about_dialog.rb:15` |
| 3 | `Back` | `src/window.blp:89` | `lib/window.rb:329` |
| 4 | `Biblioteca` | `data/app.desktop:3` | `lib/biblioteca.rb:3` |
| 5 | `Blueprint` | `src/sidebar/Sidebar.blp:96` | `lib/sidebar_menu.rb:30` |
| 6 | `Bookmarks` | `src/sidebar/Sidebar.blp:56` | `lib/sidebar_menu.rb:12` |
| 7 | `Close Search` | `src/FindOverlay.blp:61` | `lib/find_overlay.rb:191` |
| 8 | `Close tab` | `src/Shortcuts.blp:19` | `lib/shortcuts_window.rb:41` |
| 9 | `Contributors` | `src/about.js:23` | `lib/about_dialog.rb:10` |
| 10 | `DevDocs` | `src/sidebar/Sidebar.blp:102` | `lib/sidebar_menu.rb:31` |
| 11 | `Developer Documentation` | `src/sidebar/Sidebar.blp:59` | `lib/sidebar_menu.rb:24` |
| 12 | `Documentation` | `src/window.blp:30` | `lib/sidebar_menu.rb:24` |
| 13 | `Find in page` | `src/Shortcuts.blp:93` | `lib/shortcuts_window.rb:57` |
| 14 | `Find next match` | `src/Shortcuts.blp:98` | `lib/shortcuts_window.rb:58` |
| 15 | `Find previous match` | `src/Shortcuts.blp:103` | `lib/shortcuts_window.rb:59` |
| 16 | `Focus global search` | `src/Shortcuts.blp:88` | `lib/shortcuts_window.rb:56` |
| 17 | `Focus URL bar` | `src/Shortcuts.blp:108` | `lib/shortcuts_window.rb:60` |
| 18 | `Forward` | `src/window.blp:97` | `lib/window.rb:338` |
| 19 | `General` | `src/Shortcuts.blp:143` | `lib/shortcuts_window.rb:20` |
| 20 | `Go back to the previous page` | `src/Shortcuts.blp:114, src/Shortcuts.blp:78` | `lib/shortcuts_window.rb:54` |
| 21 | `Go forward to the next page` | `src/Shortcuts.blp:119, src/Shortcuts.blp:83` | `lib/shortcuts_window.rb:55` |
| 22 | `Human Interface Guidelines` | `src/sidebar/Sidebar.blp:66` | `lib/sidebar_menu.rb:25` |
| 23 | `JavaScript` | `src/sidebar/Sidebar.blp:72` | `lib/sidebar_menu.rb:26` |
| 24 | `Keyboard Shortcuts` | `src/sidebar/Sidebar.blp:111` | `lib/sidebar_menu.rb:14` |
| 25 | `Main Menu` | `src/sidebar/Sidebar.blp:13` | `lib/sidebar.rb:107` |
| 26 | `Move current tab at the end` | `src/Shortcuts.blp:64` | `lib/shortcuts_window.rb:50` |
| 27 | `Move current tab at the start` | `src/Shortcuts.blp:59` | `lib/shortcuts_window.rb:49` |
| 28 | `Move current tab backward` | `src/Shortcuts.blp:49` | `lib/shortcuts_window.rb:47` |
| 29 | `Move current tab forward` | `src/Shortcuts.blp:54` | `lib/shortcuts_window.rb:48` |
| 30 | `Navigation` | `src/Shortcuts.blp:75` | `lib/window.rb:275` |
| 31 | `New Tab` | `src/window.blp:109` | `lib/window.rb:347` |
| 32 | `No Results Found` | `src/sidebar/Sidebar.blp:32` | `lib/sidebar.rb:143` |
| 33 | `Open Sidebar` | `src/window.blp:75` | `lib/window.rb:314` |
| 34 | `Open tab` | `src/Shortcuts.blp:14` | `lib/shortcuts_window.rb:40` |
| 35 | `Python` | `src/sidebar/Sidebar.blp:90` | `lib/sidebar_menu.rb:29` |
| 36 | `Reset zoom` | `src/Shortcuts.blp:137` | `lib/shortcuts_window.rb:67` |
| 37 | `Rust` | `src/sidebar/Sidebar.blp:84` | `lib/sidebar_menu.rb:28` |
| 38 | `Search Biblioteca` | `src/sidebar/Sidebar.blp:23` | `lib/sidebar.rb:131` |
| 39 | `Shortcuts` | `src/Shortcuts.blp:151` | `lib/biblioteca.rb:15` |
| 40 | `Show Next Result` | `src/FindOverlay.blp:52` | `lib/find_overlay.rb:183` |
| 41 | `Show Previous Result` | `src/FindOverlay.blp:46` | `lib/find_overlay.rb:175` |
| 42 | `Show sidebar` | `src/Shortcuts.blp:146` | `lib/shortcuts_window.rb:70` |
| 43 | `Switch to tabs 1⋯10` | `src/Shortcuts.blp:69` | `lib/shortcuts_window.rb:51` |
| 44 | `Switch to the first tab` | `src/Shortcuts.blp:34` | `lib/shortcuts_window.rb:44` |
| 45 | `Switch to the last tab` | `src/Shortcuts.blp:39` | `lib/shortcuts_window.rb:45` |
| 46 | `Switch to the next tab` | `src/Shortcuts.blp:24` | `lib/shortcuts_window.rb:42` |
| 47 | `Switch to the previous tab` | `src/Shortcuts.blp:29` | `lib/shortcuts_window.rb:43` |
| 48 | `Tabs` | `data/app.metainfo.xml, src/Shortcuts.blp:11` | `lib/shortcuts_window.rb:20` |
| 49 | `Try a different search term` | `src/sidebar/Sidebar.blp:33` | `lib/sidebar.rb:144` |
| 50 | `Vala` | `src/sidebar/Sidebar.blp:78` | `lib/sidebar_menu.rb:27` |
| 51 | `View all open tabs` | `src/Shortcuts.blp:44` | `lib/shortcuts_window.rb:46` |
| 52 | `Zoom` | `src/Shortcuts.blp:124` | `lib/shortcuts_window.rb:20` |
| 53 | `Zoom in` | `src/Shortcuts.blp:127, src/sidebar/ZoomButtons.blp:23` | `lib/shortcuts_window.rb:65` |
| 54 | `Zoom out` | `src/Shortcuts.blp:132, src/sidebar/ZoomButtons.blp:10` | `lib/zoom_buttons.rb:49` |

**10 upstream msgids are absent from the port entirely** — all of them from the
two data files the port does not ship (see `component-parity.md`, Gap 1). These
are gaps on both axes: the string is missing *and* the file that would carry it
is missing.

| # | msgid | Upstream site |
|---|---|---|
| 1 | `Biblioteca lets you browse and read GNOME documentation. Among other things, Biblioteca comes with` | `data/app.metainfo.xml` |
| 2 | `Biblioteca main window with GTK 4 docs selected` | `data/app.metainfo.xml` |
| 3 | `Dark mode support` | `data/app.metainfo.xml` |
| 4 | `Fuzzy search` | `data/app.metainfo.xml` |
| 5 | `GTK;libadwaita;doc;documentation;api;manual;devhelp;` | `data/app.desktop:11` |
| 6 | `Learn and prototype with GNOME technologies` | `data/app.desktop:4` |
| 7 | `Mobile / adaptive` | `data/app.metainfo.xml` |
| 8 | `Offline documentation` | `data/app.metainfo.xml` |
| 9 | `Read GNOME documentation offline` | `data/app.metainfo.xml` |
| 10 | `Web browsing` | `data/app.metainfo.xml` |

## Reused messages

5 of the 64 keys reach more than one call site upstream, and the `Uses` gap is
worth recording because it is where a marked port can still drop a label:

| msgid | Upstream uses | Port literal sites |
|---|---:|---:|
| `Go back to the previous page` | 2 (`Shortcuts.blp:78,114`) | 2 |
| `Go forward to the next page` | 2 (`Shortcuts.blp:83,119`) | 2 |
| `Zoom in` | 2 (`Shortcuts.blp:127`, `ZoomButtons.blp:23`) | 2 |
| `Zoom out` | 2 (`Shortcuts.blp:132`, `ZoomButtons.blp:10`) | 2 |
| `Tabs` | 2 (`Shortcuts.blp:11`, `app.metainfo.xml`) | 1 |

`Tabs` at `1 → 2` is the metainfo feature bullet, which belongs to the missing
`data/` tree, not to a missing component.

## Strings the port invented

Not translation gaps (there is no upstream key to miss) but they are strings
the port shows a user and nobody has translated or reviewed, and they are the
reason a later `xgettext` run would disagree with upstream's catalogue:

| String | Port site | Upstream equivalent |
|---|---|---|
| `Keyboard Shortcuts` as the dialog's own title | `lib/shortcuts_window.rb:143` | GTK/Adw supplies the title; upstream sets none |
| `Two-finger swipe right` | `lib/shortcuts_window.rb:61` | `shortcut-type: gesture_two_finger_swipe_right` (an illustration, no string) |
| `Two-finger swipe left` | `lib/shortcuts_window.rb:62` | `shortcut-type: gesture_two_finger_swipe_left` |
| `Follow System Style` | `lib/theme_selector.rb:36` | unverified — `troll` not checked out |
| `Light Style` | `lib/theme_selector.rb:37` | unverified |
| `Dark Style` | `lib/theme_selector.rb:38` | unverified |

The last three are the serious ones: they are guesses at strings a real file in
a real submodule already contains.

## Unresolved markers

0 on both sides. No marker on either tree takes a non-literal argument, so no
message is hidden from the census.
