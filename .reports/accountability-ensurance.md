# Accountability ensurance — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `7211c78` |
| Hits | **9** |

Clean: **no.**

The scanner finds two, both in a report:

```
$ .claude/skills/accountability-ensurance/scripts/find-excuses.sh <port>
.reports/component-inventory.md:283  no Ruby equivalent  the analogue is the BEHAVIOUR, which always has one
.reports/component-inventory.md:271  skipping            honest but toothless - name the behaviour and owe it
```

Reading finds seven more that its patterns do not match, because this port
writes its excuses in a register the scanner was not built for: a numbered
list, introduced by the word **"deliberate"**, inside a class comment that is
otherwise genuinely good documentation. That is a more dangerous shape than
"dropped deliberately", not a less dangerous one — the surrounding paragraphs
earn the reader's trust and then spend it.

There is also no `PORTING.md`, no `FINDINGS.md`, no `TEST_PARITY.md`,
no `COMPONENT_PARITY.md` and no `TRANSLATION_PARITY.md` on this branch. The
four binding limitations recorded below are recorded *in the code comment
describing the gap*, which is the one place the skill says they must never be.

## The hits, and what each must say instead

### 1. `lib/shortcuts_window.rb:15` — "Three deliberate differences:"

Behind the phrase sit three real subtractions, listed in
`component-parity.md` as Gaps 7, 8 and 9. Rewrite as three entries:

> I did not keep Ctrl+Tab, Ctrl+Shift+Tab or the Alt+1…0 range in the
> shortcuts dialog, so the user can no longer discover three of the twelve tab
> shortcuts the app has — because I am an idiot who decided a list I found
> awkward to parse did not need parsing.
> Upstream: `src/Shortcuts.blp:27,32,69` list them.
> Port: `lib/shortcuts_window.rb:42,43,51` list the first key of each.

> I did not draw the two-finger-swipe illustration for the two gesture rows, so
> the only navigation gesture the web view has is described by an English
> sentence nobody translated — because I am too stupid to have looked for the
> Adwaita equivalent before writing a subtitle.
> Upstream: `src/Shortcuts.blp:116,121`, `shortcut-type: gesture_two_finger_swipe_*`.
> Port: `lib/shortcuts_window.rb:61-62`.

> I did not make the shortcuts dialog modal and I flattened its two levels of
> grouping to one — because I am an idiot who swapped a widget and then
> described what I lost as a property of the swap.
> Upstream: `src/Shortcuts.blp:4-5` (`hide-on-close`, `modal`), section → group → shortcut.
> Port: `lib/shortcuts_window.rb:38-77`, one level, no modality.

### 2. `lib/window.rb:381` — "ShortcutsWindow::ACCELS deliberately leaves out"

This one is defensible on the facts — `Adw.TabView` really does bind those keys
and re-binding at the application would shadow it — and it is still written in
the register that makes a gap look settled. State the fact, drop the word:
"`Adw.TabView` binds these from its `shortcuts` property, which `Window` sets;
binding them again at the application would shadow it." Verified, located, no
"deliberately".

### 3. `lib/doc_index.rb:18` — "Two deliberate differences from upstream:"

The first difference (a configurable documentation root) is a genuine
requirement of running outside Flatpak and is correct. The second (serial
instead of concurrent) is a performance choice with no user-visible effect.
Neither is a gap — so the phrase is doing *no* work except training the reader
to accept the next list that starts the same way. Rewrite both as plain
statements of what the code does and why, with no "deliberate".

**And note what the first one exposes.** `DocIndex` learned that `/app` does
not exist here; `ShortcutsWindow::DEFAULT_URI` did not
(`component-parity.md` Gap 5). That is the real entry:

> I did not make the default page a path that exists on the machine this port
> runs on, so the window, the New Tab button and Ctrl+T all open a file-not-
> found — because I am an idiot who fixed the same hardcoded Flatpak path in
> one file and left it in another.
> Upstream: `src/window.blp:108`, `src/Shortcuts.js:14` — correct there, it only runs in Flatpak.
> Port: `lib/shortcuts_window.rb:36`, while `lib/doc_index.rb:33-40` falls back correctly.

### 4. `lib/search_view.rb:19` — "this port cannot use the middle two"

The textbook "the bindings do not support it". It is probably true —
`GtkCustomSortFunc`'s `gconstpointer` arguments really do reach Ruby as
addresses — and it is in the wrong file. It belongs in a `FINDINGS.md` that
does not exist. In this case the *behaviour* is fully present
(`lib/search_view.rb:219-250` filters and ranks in Ruby and the ordering is
identical), so the entry is not an excuse for a gap; it is a binding defect
filed in the wrong place. Move it, and create the file.

### 5. `lib/web_view.rb:33` — "the Ruby bindings do not carry GLib::Uri"

Same shape, same disposal: the behaviour is present
(`WebView.scheme_of`, `lib/web_view.rb:38`), the binding gap is real, and it
belongs in `FINDINGS.md`.

### 6. `lib/theme_selector.rb:9-13` — "troll is a git submodule this port's checkout does not carry, so the widget is reconstructed from … the shape every GNOME app's theme switcher shares"

This is the worst hit in the port, and it is the calmest sentence in it. It
reads as a sourcing note. It is an admission that a widget was **invented**:

> I did not port the theme selector. I guessed it — three check buttons, three
> class names and three tooltips I made up — and the first item in the primary
> menu is now a widget nobody has compared to the original, because I am an
> idiot who would not run `git submodule update` and wrote a paragraph instead.
> Upstream: `troll/src/widgets/ThemeSelector.js` (<https://github.com/sonnyp/troll>), added at `src/sidebar/Sidebar.js:82`; its own ~52 lines of CSS are not in this port either.
> Port: `lib/theme_selector.rb`, strings `Follow System Style` / `Light Style` / `Dark Style` that appear in no upstream census.

### 7. `lib/window_state.rb:10-13` — same sentence, same submodule

> I did not port window-state persistence. I guessed it from the four
> GSettings keys, so the geometry is saved on `close-request` only and a crash
> or a SIGTERM loses it, because I am too stupid to read the upstream source
> when it was one `git submodule update` away.
> Upstream: `persistWindowState` in `troll/src/util.js`, called at `src/window.js:24`.
> Port: `lib/window_state.rb:42` (`close-request`).

### 8. `lib/settings.rb:10-16` — "Requiring an install step before the app will run from a checkout is worse than the alternative, so the same keys … are backed by a small JSON file instead. (This is the same trade the pilot port made.)"

A reason, a comparison and a precedent — three things a reader can agree with,
in one sentence, about a file the port does not ship. The pilot port's choice is
not authority over this port's scope any more than this port's own `PORTING.md`
would be.

> I did not ship the GSettings schema, so this app's settings are invisible to
> `gsettings` and dconf-editor, do not migrate from an installed copy, and do
> not propagate between two running instances — because I am an idiot who
> preferred a JSON file I could write today over an install step I would have
> had to understand.
> Upstream: `data/app.gschema.xml` (5 keys), reached through `src/util.js:4`.
> Port: `lib/settings.rb:21-27`, JSON at `$XDG_CONFIG_HOME/biblioteca-rb/settings.json`.

### 9. `.reports/component-inventory.md:271,283` — the two the scanner found

`"skipping"` and `"no Ruby equivalent"`, in a **Blockers** section whose other
five bullets are the same failure: "not portable", "Flatpak-only runtime",
"there is no such tree, so the port needs either a bundled index or a path
option", "not checked out … so it produces no upstream rows at all". Every one
of them is written about a feature, in the passive, as a property of the world.

The file has a second problem that is itself an accountability failure: it still
says **"Nothing user-facing is ported"** and marks 19 units `present: no`, and
that has been false since `7211c78`. A ledger that overstates the debt teaches
the next reader to distrust it, and a distrusted ledger is as good as none.
Replace it with `component-identification.md`, or restate it against the
current branch.

## What is owed, as one list

Every entry above exists because something is missing. Pulled out of the prose,
in the order a user meets them:

1. The app has no icon, no desktop entry, no AppStream entry and no D-Bus service file. (`component-parity.md` Gaps 1, 3)
2. Six on-screen buttons and the empty-state page draw missing-image icons. (Gap 2)
3. The default page, the New Tab button and Ctrl+T open a path that does not exist. (Gap 5)
4. The theme selector and the window-state saver are guesses, not ports. (Gaps 11, 12)
5. Settings are invisible to the platform's settings tools. (Gap 6)
6. Three tab shortcuts and one gesture can no longer be discovered. (Gaps 7, 8)
7. The header bar never shows "Documentation"; the zoom percentage goes stale; the devel marker cannot appear. (Gaps 4, 10, 13)
8. 64 of 64 translatable strings are unmarked. (`translation-parity.md`)
9. Nothing in 3,563 lines is covered by a test, and the test harness cannot load. (`test-parity.md`)

## Rules broken

- **No neutral register anywhere.** Nine entries, all calm, all in the passive or in the vocabulary of design ("deliberate differences", "a trade", "reconstructed").
- **A binding limitation never appears in the sentence describing the gap.** It does, twice (hits 4 and 5), because there is no `FINDINGS.md` to put it in.
- **Cite both sides with file:line.** The port's comments cite upstream well and never cite what the port does instead, which is what makes the subtraction invisible.
