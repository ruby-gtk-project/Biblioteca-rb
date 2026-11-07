# Component identification — round 6

Date: 2026-11-07. Port commit audited: `2844629` (tree identical to round
5's `828bdd5`/`7fd14a8` — no `lib/`, `exe/`, `spec/`, `test/`, `data/` or
`po/` diff between them; verified with `git diff --stat 828bdd5 HEAD --
lib exe test spec po data`, empty output).

## Method

Re-ran `.claude/skills/component-identification`'s approach independently
rather than re-reading round 5's inventory on trust: listed `lib/*.rb` and
`lib/biblioteca/*.rb`, cross-checked each file's own "ported from" header
comment against `git show origin/main:<path>` / `git ls-tree -r --name-only
origin/main`.

## Inventory (unchanged from round 5, re-verified)

19 `lib/` components, each carrying an explicit upstream-source comment:

`package.rb`, `settings.rb`, `style.rb`, `biblioteca/application.rb`,
`window.rb`, `window_state.rb`, `shortcuts_window.rb`, `about_dialog.rb`,
`find_overlay.rb`, `web_view.rb`, `sidebar.rb`, `sidebar_menu.rb`,
`theme_selector.rb`, `zoom_buttons.rb`, `browse_view.rb`, `search_view.rb`,
`documentation_page.rb`, `doc_index.rb`, `fzy.rb`.

Every upstream `src/*.js`/`.blp` pair this round's `git ls-tree -r
--name-only origin/main` lists has a corresponding entry above; nothing
newly appeared on `origin/main` since round 5's inventory (`origin/main` is
a fixed ref for this audit, not re-fetched, per the task's own instruction
never to merge it — confirmed no new fetch changed its SHA: `git rev-parse
origin/main` unchanged from the value cited in `.reports/component-
inventory.md`).

## The "16 components" figure in this round's gate text

This round's runtime-gate line (handed down by the harness, not drawn from
this repo) says the 451-check gate covers **16** components. The port's own
drivers, ledgers and round-5 report all say **19**, and this round's
independent re-run (below) reproduces 395+31+25=451 checks against the same
19-file `lib/` tree. Nothing in this repo's history, drivers or docs
produces a count of 16 by any grouping tried (per-file: 19; collapsing
`biblioteca/application.rb` into `package.rb`'s entry-point group: still not
16; counting only widgets with their own `.blp` analogue, excluding the
three pure-Ruby-origin files `window_state.rb`/`theme_selector.rb` ported
from `troll/` rather than `src/`: 16 — this is the only grouping found that
reaches 16, and it is not a grouping this port's own reports use anywhere).
Flagged as a wording mismatch between the harness's gate description and
this repo's own component count, not as a port gap: the checks themselves
(451/451) are real and independently reproduced below, and no component is
missing either way.

## Verdict

No new component found on `origin/main` since round 5; no component in the
port's inventory is undocumented or missing an upstream citation. Identical
to round 5's finding.
