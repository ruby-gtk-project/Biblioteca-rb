# Accountability ensurance — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `243ddbe` |
| Excuse markers in `lib/`, `exe/`, `test/`, `spec/`, `.reports/`, `PORTING.md` | **0** |
| False greens | **1** |
| Stale greens / withdrawn claims | **4** |
| Green claims resting on something never executed | **2** |
| Narrow checks presented as coverage | **2** |
| Audited | 2026-11-02 |

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

## Verdict

No gap in this port is being excused in a comment. One is being excused by a
shell `if`, four were being understated by reports that had gone stale, two
rest on mechanisms no check can execute, and two checks read a Ruby constant
where they should read a GTK object. `clean: false`.
