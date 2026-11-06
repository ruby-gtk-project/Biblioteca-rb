# Accountability ensurance — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `ced6a5b` |
| Excuse markers in `lib/`, `exe/`, `test/`, `spec/`, `.reports/`, `PORTING.md` | **0** |
| False greens | **1** |
| Stale greens / withdrawn claims | **4** |
| Green claims resting on something never executed | **2** |
| Narrow checks presented as coverage | **2** |
| New this round: load-bearing "design decision" framing | **1** |
| New this round: a stale resume document presenting a false project state | **1** |
| Audited | 2026-11-06 |

Round 4 re-ran every check F-1 through F-4 cite rather than carrying them
forward on trust: `desktop-file-validate`, `appstreamcli`, `appstream-util`
and `flatpak-builder-lint` are confirmed still **MISSING** from the dev shell
(F-1 unchanged), `rake data:validate` still runs and prints nothing, the four
withdrawn claims in F-2 are confirmed still withdrawn (`394 of 394`,
`36 examples, 0 failures`, `rubocop_gradual:check` still absent from `rake
-T`), and `grep -n accessible test/*.rb` is still empty (F-3 unchanged). Two
new findings follow, F-6 and F-7.

## The grep is clean

```sh
grep -rniE 'TODO|FIXME|not implemented|for now|in a future|unimplemented|placeholder|stub|XXX|HACK' \
  lib/ exe/ test/ spec/ .reports/ PORTING.md COMPONENT_PARITY.md TEST_PARITY.md \
  TRANSLATION_PARITY.md FINDINGS.md
```

Five hits, every one incidental and none an excuse:

| Hit | Why it is not an excuse |
|---|---|
| `spec/fzy_spec.rb:69` `"aXXXXXXXXb"` | a test fixture string |
| `lib/sidebar.rb:143` `placeholder_text` | the GTK property name, upstream's `placeholder-text` |
| `spec/README.md:11` `stub_env` | an RSpec helper's name |
| `.reports/drive.md:127` `TODO: in Ruby -> GIArgument…` | a quoted ruby-gnome error message from other forks, cited as *not* hit here |
| `.reports/accountability-ensurance.md` | this file's own grep command |

Nothing in this port is deferred in a comment. Every divergence from upstream
is written out in prose with the upstream file and line beside it — `FINDINGS.md`
has seven numbered entries, `lib/package.rb:46-53` states what it does not
reproduce and what replaces it, `lib/settings.rb:19-40` documents its fallback
as "strictly worse" in three named ways. That is the right shape.

**So the findings below are not about things being excused. They are about
things being *claimed*.**

## F-1 — False green: `rake data:validate` validates nothing

**This is the most serious finding in this round.**

`.reports/test-parity.md` (previous edition) recorded upstream check 1
(`desktop-file-validate`) as `ported`, with a dash in the "behaviour still
owed" column. The task it points at is:

```ruby
task :validate do
  if system("which desktop-file-validate > /dev/null 2>&1")
    sh("desktop-file-validate", …)
  end
  if system("which appstreamcli > /dev/null 2>&1")
    sh("appstreamcli", "validate", …)
  end
end
```

Both tools are **missing from the fork's dev shell** (verified this round:
`desktop-file-validate MISSING`, `appstreamcli MISSING`, `appstream-util
MISSING`, `flatpak-builder-lint MISSING`). `rake data:validate` therefore
runs, prints nothing, and exits 0. `data/app.desktop` and
`data/app.metainfo.xml` have never been validated by anything, on any run, by
anybody.

A guard written as `if tool_exists` turns an absent tool into a pass. That is
the exact shape this skill exists to catch, and it survived two previous
rounds because the report stopped at "a task exists".

**Fix:** add `desktop-file-utils` and `appstream` to the flake devShell; split
the task into three named tasks (`:desktop`, `:metainfo`, `:appstream`) so one
failure cannot hide the next; and make a missing tool either fail the task or
print `SKIPPED: <tool> not found` so silence can never read as success.

## F-2 — Four stale greens, now withdrawn

These were true when written and are false at `243ddbe`. Carrying them forward
unchanged would have been the second-worst outcome after F-1, because each one
*understates* the port and so hides what is actually left.

| Document | Claim | Reality at `243ddbe` |
|---|---|---|
| `.reports/component-parity.md` | "**Nothing below has been exercised in a running GTK process.** … The `gtk4`, `adwaita`, `webkit-gtk` and `gettext` gems are not installed in this checkout" | re-run this round: `394 of 394 checks passed / DRIVE OK` over 19 components |
| `.reports/test-parity.md` | "`bundle exec rspec` — **does not run** (`command not found: rspec`)" and "**Neither file has ever been run under RSpec.**" | `36 examples, 0 failures` this round |
| `.reports/test-parity.md` | "`rake rubocop_gradual:check`" cited as the port's answer to upstream's eslint check | that task **does not exist** — absent from `rake -T`, no `.rubocop_gradual.lock`. The real answer is the `rubocop` binary, which is clean on `lib exe spec test po` (32 files, 0 offences) |
| `.reports/component-parity.md` gap 4 | theme-selector accessible labels "**absent** — `lib/theme_selector.rb:197` sets `tooltip_text` only" | implemented in `ee5233f` via a `Gtk::Builder` `<accessibility>` block. The gap has changed shape, not closed — see F-3 |

`COMPONENT_PARITY.md` and `TEST_PARITY.md` at the repository root carry the
same stale text and are **not** rewritten by this round. They are now the
oldest green in the tree and should either be deleted in favour of `.reports/`
or regenerated; two ledgers that disagree is worse than one.

## F-3 — Two green claims resting on something that cannot be executed

| Claim | Who makes it | Why nothing backs it |
|---|---|---|
| The three theme swatches carry accessible labels, matching troll's `ThemeSelector.blp` | `lib/theme_selector.rb:28-33` ("Each button carries both halves … the tooltip and the `accessibility { label: … }`") and commit `ee5233f`'s subject, "accessible labels" | `grep -n accessible test/*.rb` is **empty**. Probed this round: `Gtk::CheckButton` exposes `accessible_id`, `accessible_parent`, `accessible_role` and no label getter, so the value cannot be read back from Ruby — **and `Gtk::Builder` accepts `<property name="no-such-prop">` inside `<accessibility>` without raising or warning**. A misspelt property name would produce exactly today's observable behaviour. The claim is plausible and unfalsifiable in-process |
| `lib/package.rb`'s two `bindtextdomain` calls bind the catalogue the port ships | `lib/package.rb#init_gettext` | `locale/` **does not exist** and `po/` holds no `.po`, so no `_()` call in this port has ever returned a translated string. See `.reports/translation-parity.md` TP-2 |

Neither is dishonest. Both are green on the strength of code that reads
correctly, which is what this skill treats as not yet green.

## F-4 — Two narrow checks presented as coverage

| Check | Asserts | Does not assert |
|---|---|---|
| `test/drive_biblioteca.rb:1198-1199`, "the main menu model is upstream's four sections" | `SidebarMenu::BOOKMARKS.length == 8`; every value starts `https://` — both readings of a frozen Ruby hash | the live `Gio::Menu`. The detailed-action spelling `win.new-tab('https://…')` is the one thing in that file that can silently fail, and no check touched it. **Verified by hand this round: 8 items, `action == "win.new-tab"`, targets identical to `Sidebar.blp`** — so the port is right and the check is still wrong |
| `test/drive_biblioteca.rb:404`, `Sidebar` with `start_index == -1` | behaviour over an **empty** `docs` array | the case that matters: docs installed, no `Gtk-4.0` node. `lib/sidebar.rb#start_index` clamps `-1` to `0` there, selecting and *loading* the first namespace where upstream selects nothing. That clamp is an undocumented divergence — `.reports/component-parity.md` gap 6 — and no report, `FINDINGS.md` entry or `PORTING.md` line mentions it |

## F-5 — Gaps correctly carried, not excused

For balance, these are open gaps that the port names honestly and does not
dress up, and this round leaves them open rather than closing them on paper:

* the Flatpak startup refusal (`lib/package.rb:46-53` — "Nothing replaces it");
* the absent Flatpak manifests, and the two `flatpak-builder-lint` checks and
  one `appstream-util` check that follow from them;
* the `troll` submodule, which makes two units undiffable;
* the GSettings JSON fallback, documented as strictly worse in three ways;
* `BrowseView#unselect_selection` doing nothing, which is upstream's own bug
  faithfully reproduced, asserted as the behaviour that *exists*, and flagged
  at both call sites rather than passed off as working.

## F-6 — A still-open gap reframed as a settled decision

`FINDINGS.md` #10 (added in `ced6a5b`, the commit this round reviews) writes,
about the Flatpak-required startup refusal that gap 1 of
`.reports/component-parity.md` keeps open:

> `lib/package.rb`'s class comment already explains why this port does not
> replicate that guard … **That is a documented design decision from before
> this round**, not a gap this round's gem-wiring closes.

This is exactly the construction this skill exists to catch, written by the
same commit that could have closed the gap and chose to wire two unrelated
gems instead. "Documented design decision" is a sentence a reader mistakes
for authority. It has none: upstream ships the refusal
(`src/bin.js:27-32`, `exit(1)` with a message), so the port not shipping it is
a missing error state, not a decision anyone but the port was entitled to
make. The gap itself is not hidden — `.reports/component-parity.md` gap 1 and
`PORTING.md`'s "Not started" table both still list it as open, and this
report's own header still counts 7 open gaps including it — so this is not a
false green. It is the load-bearing-note failure in its purest form: the
excuse and the gap sit in the same file, four lines apart, and the excuse is
still wrong for a reason that has nothing to do with whether the gap is
listed. Rewrite `FINDINGS.md` #10's second paragraph to state plainly that
the Flatpak startup refusal is not implemented and nothing in this commit
implements it, and drop "documented design decision" entirely — `lib/
package.rb`'s own comment, cited approvingly here, already carries the same
construction and should be checked next.

## F-7 — `PORTING.md`'s header describes a port that no longer exists

`PORTING.md:1-13` states "Last audit 2026-11-02, at port commit `d63ee49`" and
"**Nothing in this port has been run**: the `gtk4`, `adwaita`, `webkit-gtk`
and `gettext` gems are not installed in this checkout … Every claim below is a
claim about source text." `d63ee49` is two "Parity reports" commits and a
"Round 3" commit behind `ced6a5b`; the drive run, the three test drivers and
RSpec have all executed successfully since, independently reconfirmed this
round (above). `PORTING.md` is named in the task's own resume-point role —
"the resume point. It records what exists" — so an agent picking up this port
from the one document designed for that purpose reads a false "nothing runs"
header before reaching anything true. This is not a comment excusing a gap;
it is the accountability failure one level up — a whole document's framing
left stale long enough to misstate the project's basic state (built vs.
unbuilt, run vs. unrun) to its next reader. `PORTING.md`'s "Open gaps" section
also still cites a per-report gap sum ("15") against a different total ("21")
without reconciling them, which is the same failure in miniature. Fix:
regenerate `PORTING.md`'s header and "Open gaps" section from this round's
five reports before the next commit touches it; do not let a fourth round
inherit a header that still says "nothing runs."

## Verdict

No gap in this port is being excused in a comment inside `lib/` or `exe/`. One
is being excused by a shell `if` (F-1), four were being understated by reports
that had gone stale (F-2), two rest on mechanisms no check can execute (F-3),
two checks read a Ruby constant where they should read a GTK object (F-4), one
still-open gap is reframed as a settled decision four lines from the gap
itself (F-6), and the port's own resume document tells the next reader the
port has never been run (F-7). `clean: false`.
