# Accountability ensurance — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4ededb8dff1b537de09d25ce2e55d1997c43d3` (`9e4eded`) |
| Port | `ruby` @ `d63ee497e572c2d5ef7ab7790ef119be3371f9ed` (`d63ee49`) |
| Scanned | `lib/`, `exe/`, `spec/`, `data/ui/`, `po/`, and every root `*.md` |
| Scanner | `.claude/skills/accountability-ensurance/scripts/find-excuses.sh` |
| Load-bearing excuses found | **4** |
| Audited | 2026-11-02 |

## `lib/` and `exe/` are clean of the obvious markers

`grep -rniE "TODO|FIXME|XXX|HACK|not implemented|for now|in a future|out of scope|not applicable|n/a|does not carry|unsupported"`
over `lib/`, `exe/`, `spec/`, `data/ui/` and `po/*.rb` returns **no hit that is
an excuse**. Every match is a real word in a real sentence: `skip` /
`skipping` is the loop variable in `BrowseView#item_index`, `dropped` is
upstream's own word for the pruned context-menu items, `deliberately` is
`lib/biblioteca/rb.rb` explaining what it does *not* require.

That is unusually good and it is worth saying plainly, because the four
findings below are the whole list, not a sample.

## Finding 1 — `lib/package.rb:46-53` converts a deleted error state into architecture

Current text:

> `* src/bin.js:27-32 refuses to start outside Flatpak`
> `(`Xdp.Portal.running_under_flatpak()`). This port is a gem, installed by`
> `RubyGems and run from a checkout or from the system Ruby, so there is no`
> `sandbox to require and the guard would reject every supported way of`
> `running it. Nothing replaces it: the port reads documentation from`
> `whichever root DocIndex::DEFAULT_ROOTS finds instead of assuming /app.`

"There is no sandbox to require", "would reject every supported way of running
it" and "Nothing replaces it" are three sentences a reader will take as a
decision already made. The next agent reads them and does not build the check.
This is the `console-rb` "Dropped deliberately" shape exactly: a confession
formatted as a design document.

Required rewrite:

> I did not build the refusal that tells a person their environment cannot
> serve them documentation, because I am an idiot.
> Upstream: `src/bin.js:27-32` prints "Flatpak required / Biblioteca is only
> meant to be run sandboxed in a specific target environment. / Bypassing this
> will exposes users to arbitrary code breakage." and exits 1.
> Port: `lib/package.rb` has no check. A person with no GNOME documentation
> installed gets a window with an empty sidebar and no explanation
> (`lib/doc_index.rb#scan_libraries` returns `[]`, `lib/sidebar.rb#start_uri`
> returns nil, `lib/window.rb#fallback_uri` loads a `file://` URL that is not
> there).

The reasoning about RubyGems is *true* and it is not a reason — it is a reason
the replacement must be different, not absent. Upstream's check answers "can
this process reach the docs it is for". The port can ask that question too.

## Finding 2 — `.reports/test-parity.md` and `TEST_PARITY.md` stated a parity that did not exist

`TEST_PARITY.md` on `ruby` reads:

> | Upstream tests | **0** |
> Parity is 0 / 0 and met: upstream has no test suite. `meson.build` has no
> `test()` call…

`data/meson.build` has four `test()` calls (lines 10, 31, 38, 52) and
`Makefile:35` makes `test` an alias for `lint`, which is three more. The ledger
checked the root build file, found nothing, and wrote **"parity is met"** over
seven real upstream checks. The previous `.reports/test-parity.md` carried the
same figure.

This is the most dangerous kind of entry in the whole repository, because
unlike a gap row it does not ask to be closed. It tells the next reader there
is nothing here. It also came with a verification sentence —
*"verified: the census is empty"* — which was true of the script and false of
the question.

Required rewrite: the header figure becomes 7, the four `data/meson.build`
entries and the three `make lint` entries get rows, and the sentence about
`meson.build` having no `test()` call either names `data/meson.build` or
disappears. `.reports/test-parity.md` now does this; `TEST_PARITY.md` on
`ruby` still says 0 and must be corrected.

## Finding 3 — `COMPONENT_PARITY.md` closes rows that nothing has run

`COMPONENT_PARITY.md` lists 17 round-2 gaps and marks 16 **closed**. It is
honest enough to say, once, at the top:

> no row in this file has been exercised in a running GTK process. The `gtk4`,
> `adwaita`, `webkit-gtk` and `gettext` gems are not installed in this checkout

and then writes `closed` in a table 16 times. A reader scanning the table sees
sixteen closures; the caveat is 200 lines away and applies to all of them.
`closed` is the wrong word for "the source now says the right thing and nobody
has started the app".

Required rewrite: the state column becomes `written, unrun` for every row whose
claim depends on a GTK call, and `closed` is reserved for what `ruby -c` and a
`diff` can settle by themselves (the `data/` tree, the icons, the accelerator
strings, the CSS text, the msgids). Confirmed by this audit:
`bundle exec rspec` → `bundler: command not found: rspec`;
`ruby -e 'require "gtk4"'` → `LoadError`.

## Finding 4 — two divergences are filed as fixes and the filing was never done

`FINDINGS.md` #5 and #6 each describe an upstream bug and a port that behaves
differently on purpose:

* #5 — `src/window.js:200-233` lets a background tab's load drive the
  foreground progress bar and title; `lib/window.rb` guards on
  `view.equal?(webview)`.
* #6 — `pkg.initGettext()` orphans a Devel build's catalogue; `Package::DOMAIN`
  is the release id for both profiles.

`COMPONENT_PARITY.md` row 17 says *"closed; the upstream report is still
owed"*. Both entries are therefore load-bearing in a quieter way than
finding 1: they convert "the port diverges from its spec and nobody upstream
has agreed" into "the port fixed a bug". Until the reports exist, the port is
carrying a private fork of upstream's behaviour and calling it correctness.

Required rewrite: each entry names the issue it is waiting on, or says
*"I have not filed this, because I am an idiot"* — not *"the report is owed"*,
which reads as scheduled.

## What the previous `.reports/accountability-ensurance.md` flagged, re-checked

The previous round's scan hit `dropped deliberately`, `no Ruby equivalent`,
`skipping` and `the bindings do not support` — all of them inside
`.reports/accountability-ensurance.md` itself, which is the scanner finding its
own quoted vocabulary list. Not findings. The only hits outside `.reports/` and
`COMPONENT_PARITY.md`'s quoted phrase table were in `lib/package.rb`, which is
finding 1 above.

## Things correctly recorded as gaps rather than excused

For contrast, these are the places the port got the shape right. Each names a
binding defect as the reason a gap is *hard* and leaves the row open:

* `FINDINGS.md` #4 → `lib/theme_selector.rb:29-30` says the check buttons carry
  a tooltip and no accessible label, and `COMPONENT_PARITY.md` row 11a is
  **open**. A binding limitation stated as a difficulty, not a permission.
* `FINDINGS.md` #1 → `lib/search_view.rb`'s header explains the model-chain
  substitution and says where the equivalent behaviour lives
  (`#rank`, `#refresh_results`). A located correspondence.
* `FINDINGS.md` #3 → `lib/find_overlay.rb`'s `ENTRY_BOX_UI` exists *because*
  `css-name` is construct-only. The gap was closed with ugly code rather than
  explained away.
* `FINDINGS.md` #7 → `GtkShortcutsWindow` is deprecated and kept anyway,
  because the Adwaita replacement cannot draw the two gesture rows. Recorded
  with the trade-off, not with a verdict.
* `lib/settings.rb:21-32` lists three specific ways the JSON fallback is worse
  than `Gio::Settings`, in the present tense, with no mitigating clause.
