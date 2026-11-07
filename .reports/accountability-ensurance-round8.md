# Accountability ensurance — round 8

Date: 2026-11-07. Port commit audited: `781d5f1`. Diff since round 7's
`7dfed31`: `COMPONENT_PARITY.md`, `flake.nix`, `rakelib/default.rake`,
`test/drive_middle_click.rb` (new), six `build-aux/*.json` files (new).
No `lib/`, `spec/`, `po/`, or `data/` diff.

## Grep for excuse language, `lib/` and `exe/`

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future" lib/ exe/
```

Zero hits. Unchanged across every round so far.

## `.claude/skills/accountability-ensurance/scripts/find-excuses.sh` over the whole tree, including `.reports/`, `PORTING.md`, `COMPONENT_PARITY.md`, `FINDINGS.md`

Ran fresh this round. Every hit traced:

- `FINDINGS.md:334` (`n/a`) — same finding rounds 5-7 already cleared: an
  honest first-person admission paired with it, not an excuse.
- `COMPONENT_PARITY.md:63,65,265,393`, `PORTING.md:68` (`not ported`,
  `design decision`, `skipped`) — all historical ledger rows marked
  closed, or factual description of the gi-docgen fixture skip. No new
  hit here this round.
- `.reports/*-round5.md` through `-round7.md`, `.reports/component-
  parity.md`, `.reports/test-parity.md`, `.reports/accountability-
  ensurance.md` — prior rounds' own audit prose quoting these phrases to
  analyze them. Self-reference, not new excuses.
- The one hit worth naming individually: `grep -rn "394 of 394"` across
  the whole tree now returns **zero hits inside `COMPONENT_PARITY.md`
  itself** (the file round 5-7 flagged). The only surviving "394 of 394"
  strings are in `PORTING.md:121` (explicitly narrating the fix: "...this
  file cited 394 of 394...") and inside prior rounds' own `.reports/*.md`
  (historical record of what was once true). Neither is a current false
  claim — the live ledger line now reads "395 of 395 checks (451...".
  This closes the staleness escalation round 7 raised.

No hit this round presents an unmade decision as a made one, or asserts a
need was never evaluated when upstream already shipped the behaviour.

## The new commit's own honesty, checked against what it actually does

Commit `781d5f1`'s message makes three claims and states two explicit
limitations in the same breath. Each was independently checked rather
than taken on the commit's word:

1. "8 of 8 steps pass" (`test/drive_middle_click.rb`) — re-run live this
   round: **true**, 5 + 3 = 8, 0 failures. The script's first assertion
   also independently re-reproduces the underlying binding bug
   (`current_button` stays 0 under `signal_emit`) before proving the real
   X11 event takes the branch — this is evidence, not a bare claim.
2. "flatpak-builder-lint itself could not be run in this sandboxed
   environment (not in nixpkgs, not already present...)" — independently
   checked: `which flatpak-builder-lint` and `which flatpak-builder` both
   fail inside the dev shell. True, not an excuse dressed as a limitation
   — the commit does **not** claim the manifest lints clean or builds; it
   explicitly says the module "does not yet vendor the app's six runtime
   gem dependencies... so this is lint-checkable but not yet
   build-complete." This is the correct shape: a limitation stated
   plainly, with the gap it leaves open named, not smoothed over. Recorded
   as still-open in `.reports/component-parity-round8.md` precisely
   because the commit itself does not claim otherwise.
3. "gh issue create against sonnyp/Biblioteca was denied by the sandbox
   as an external system write" — this is a claim about environment
   policy, not something independently re-executable from here (this
   audit session has the same sandbox). No upstream issue exists on the
   `ruby` branch or anywhere in this checkout to check against, so the
   claim is taken as a documented constraint, same treatment round 5-7
   gave the AT-SPI a11y-bus constraint. It does not change gap 1's
   "still open" status in `.reports/component-parity-round8.md` — the
   bugs remain unfiled against upstream regardless of why.

## Green claims checked against something actually executed, this round

- "395 checks / 0 failed" (task gate figure) — re-run live: real.
- "459 driver checks, 0 failed" (451 + the new 8) — all four drivers
  re-run live this round, not taken on the commit message's word.
- "64/64 msgids" — re-counted fresh: real.
- "38 RSpec examples, 0 failures" — re-run fresh: real.
- "395 of 395 (451 combined)" now in `COMPONENT_PARITY.md` — checked
  against this round's own live driver re-run, not against the commit's
  narration of what it changed: matches exactly.

## Verdict

No gap in this port is being excused rather than built this round. The
two gaps closed this round (middle-click driving, the stale count) are
closed with the strongest kind of evidence this audit has seen — a real
synthesized X11 event and a direct grep against current file content,
not a narrative claim taken on faith. The one gap that moved without
fully closing (the Flatpak manifest) is handled correctly by its own
commit message: it states the manifest's incompleteness itself, in the
same breath as introducing it, rather than claiming packaging is done.
This audit keeps it open regardless. The two gaps that remain fully open
(upstream bug filing, AT-SPI label verification) are both backed by
re-confirmed, concrete environment constraints, not hand-waving.
`clean: false` — three open component-parity gaps remain (1, 4, 5 in
round 8's numbering), and the runtime gate is genuinely green,
independently reproduced in this session.
