# Accountability ensurance — Biblioteca-rb — round 5

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `828bdd5` |
| Excuse markers in `lib/`, `exe/` | **0** |
| False greens found this round | **0** |
| Stale ledger numbers found this round | **2** |
| Documentation (not correctness) gaps found this round | **1** |
| Audited | 2026-11-07 |

## Method

```
grep -rniE 'TODO|FIXME|not implemented|for now|in a future' lib/ exe/ .reports/ PORTING.md
bash .claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

## `lib/` and `exe/`: clean

The `TODO|FIXME|not implemented|for now|in a future` grep over `lib/` and
`exe/` returns **nothing**. Every hit the broader grep (also scoped to
`.reports/` and `PORTING.md`) surfaces is one of:

- a quoted ruby-gnome error string from a *different* fork in this fleet,
  cited in `.reports/drive.md` as a bug this port does **not** hit (confirmed:
  `Adwaita::Breakpoint`/`add_breakpoint` are exercised directly and pass in
  this round's drive run, not routed around);
- `FINDINGS.md`'s own description of the Flatpak-refusal gap, correctly
  stating in first person that it was not implemented before round 4 and is
  partially implemented now (an adapted check, not upstream's literal guard)
  — a true statement about a real, still-partially-open item, not an excuse
  for it.

No instance of "for now", "in a future [version]", "not implemented" or a
bare `TODO`/`FIXME` sits in the port's own source or exe. This matches the
round-4 report's finding of 0 excuse markers in those two trees, re-verified
rather than assumed.

## `find-excuses.sh .`: every hit checked by hand

The script's strong-pattern hits ("design decision", "not ported", "skipped",
"unported") all land in `.md` ledgers, never in `lib/`/`exe/`. Each one was
opened and read, not just counted:

| Hit | Verdict |
|---|---|
| `COMPONENT_PARITY.md:254` "a settled design decision" | **Not an excuse.** The sentence reads "...rewritten to say so plainly rather than call it a settled design decision" — it is the ledger explicitly disclaiming the old excuse, not making a new one. |
| `COMPONENT_PARITY.md:52,54` "not ported" | Historical status column, now "closed" in the same row. Not a live excuse. |
| `COMPONENT_PARITY.md:366` "skipped" | Refers to `drive_app.rb`'s 2 skipped steps (no gi-docgen docs on this machine), which is named, explained, and covered by a second driver (`drive_sidebar.rb`) built specifically to close that hole. Not an excuse for missing coverage — a stated environment limit with a worked-around consequence. |
| `PORTING.md:89` "unported" | `src/init.js:8`'s `Gtk.UriLauncher` call, which `FINDINGS.md` and `COMPONENT_PARITY.md` both independently confirm has no call site anywhere in `origin/main` (`grep -rn UriLauncher` over upstream finds the one promisified declaration and nothing that invokes it). Dead code upstream has no behaviour to owe. Verified by re-running the grep this round, not taken on the citation alone. |
| `.reports/*.md:` various "design decision"/"skipped" | All inside `.reports/accountability-ensurance.md` and `.reports/component-parity.md` themselves, i.e. this skill's own prior output *quoting* the excuses it found and is rewriting — not new live excuses. |

**Zero live excuse constructions found this round.** Every hit the script
raises is either resolved, historical, or the skill's own prior finding being
quoted for the record.

## Checking the three "still owed" rows for quiet downgrade

A live risk this skill exists to catch: a gap that was open, got reworded
into something that sounds smaller, without actually closing it.
`COMPONENT_PARITY.md`'s five "still owed after round 4" rows were each
independently re-verified this round in `.reports/component-parity-round5.md`
(filed upstream reports still not filed; `rake data:install` still unrun;
gestures still undriven; no Flatpak manifest still exists;
AT-SPI label value still unread). None were reworded into a weaker claim —
the wording matches round 4's, and the underlying fact matches the wording.

## New this round: two stale numbers, not false greens

1. `COMPONENT_PARITY.md:364` and `PORTING.md` still cite **"394 of 394"**
   drive checks. The actual, independently re-run figure this round (and,
   per the round-5 commit, since round 4 landed the extra
   `start_uri`/no-Gtk-node check) is **395 of 395**, and the combined
   three-driver gate is **451**. The ledger was not updated to the new
   number when the check count changed. This is not a false green — 394/394
   was true when it was last measured, and 395/395 is still a pass — but a
   reader comparing "394 of 394" in the ledger against a live "395 of 395"
   run would reasonably wonder whether something regressed. Recorded as a
   staleness finding, fix: update both files' drive-count citations to
   395/395 (or 451 combined) in the next ledger edit.
2. `TEST_PARITY.md`'s "Test command" cell says `bundle exec rspec`, which
   **fails outright** on this checkout (`Gem::Exception`, rspec-core not a
   bundler executable) — the working command is the longer `ruby -e
   'require "rspec/core"; ...'` form the dev shell banner prints. Detailed in
   `.reports/test-parity-round5.md`. This is the more serious of the two: a
   reader who runs exactly what the ledger tells them to run gets an
   exception, not a test report, on their very first command.

Neither of these is a gap being excused — both are reported here plainly,
with the fix named, which is the opposite of what this skill exists to
catch. They are filed as findings precisely because leaving a stale number
or a broken documented command sitting unflagged is itself how a false green
starts.

## Verdict

No gap in this port is currently being excused rather than built. The five
component-parity gaps, the 0/0 test-parity floor, and the translation-parity
claims are all stated plainly, carry no "documented design decision" cover,
and were independently re-verified this round rather than carried forward on
trust. Two pieces of ledger staleness were found and are recorded above so
they do not calcify into a false green on the next pass.
