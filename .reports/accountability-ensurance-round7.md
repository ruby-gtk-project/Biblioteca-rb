# Accountability ensurance — round 7

Date: 2026-11-07. Port commit audited: `7dfed31`. Diff since round 6's
`2844629`: `PORTING.md` (+33/-8) and `TEST_PARITY.md` (+1/-1) only — no
application code changed (`git diff --stat 828bdd5 HEAD -- lib exe test
spec po data rakelib` is empty).

## Grep for excuse language, `lib/` and `exe/`

```
grep -rniE "TODO|FIXME|not implemented|for now|in a future" lib/ exe/
```

Zero hits. Unchanged across every round so far.

## `.claude/skills/accountability-ensurance/scripts/find-excuses.sh` over the whole tree, including `.reports/` and `PORTING.md`

Ran fresh this round (not re-reading round 6's output). Every hit read:

- `FINDINGS.md:334` (`n/a`) — same finding round 5/6 already cleared:
  labelled as "not a port divergence," immediately paired with an honest
  first-person admission elsewhere in the same finding. Not an excuse.
- `COMPONENT_PARITY.md:52,54,254,366`, `PORTING.md:68` (`not ported`,
  `design decision`, `skipped`) — all historical ledger rows marked
  **closed**, or factual description of the 2-skip gi-docgen fixture
  (re-confirmed passing this round in `.reports/test-parity-round7.md`).
  Line 364's "394 of 394" is the one line here that is *not* clean — see
  below, it is the staleness gap, not an excuse.
- `.reports/*-round5.md`, `.reports/*-round6.md`, `.reports/component-
  parity.md`, `.reports/test-parity.md`, `.reports/accountability-
  ensurance.md`, and this round's own `.reports/component-parity-
  round7.md` and `.reports/test-parity-round7.md` — all hits are prior or
  current rounds' own audit prose discussing these same phrases (quoting
  them to analyze them). Not new excuses; self-reference, same shape every
  round.

No hit this round presents an unmade decision as a made one, or asserts a
need was never evaluated when upstream already shipped the behaviour.

## Green claims checked against something actually executed, this round

- "395 checks / 0 failed" (the task's own gate figure) — independently
  re-run live in `.reports/component-parity-round7.md`: real.
- "451 checks / 0 failed" (395 + 31 + 25) — same, all three drivers re-run
  live this round, not taken on `PORTING.md`'s word.
- "64/64 msgids" — independently re-counted in `.reports/translation-
  parity-round7.md`: real, `grep -c` run fresh.
- "38 RSpec examples, 0 failures" — independently re-run in `.reports/
  test-parity-round7.md`: real.
- "`rake data:install` closes gap 2" — the single claim most worth
  distrusting on sight, because it is exactly the shape of a false green
  (a ledger says a thing works; nobody re-ran it). Re-ran it this round
  against a **fresh** prefix (`/tmp/biblioteca-install-verify`, not
  reusing round 6's directory) and inspected the resulting file tree
  directly: desktop entry, metainfo, D-Bus service, compiled GSettings
  schema, and the full icon tree all present. Confirmed real, not a false
  green.
- "`TEST_PARITY.md`'s Test command now works" — re-ran the exact string in
  the cell and got 38/0. Also re-ran the *old* string (`bundle exec
  rspec`) as a negative control and confirmed it still raises — proving
  the fix changed something real, not just the text.
- "19 components" (the port's own figure) vs. the gate text's "16" —
  re-derived again this round in `.reports/component-identification-
  round7.md`: still 19 by every grouping this repo's own docs use, still
  not reproducible as 16 by any grouping. Third round this mismatch is
  recorded; it remains a wording issue in the harness-supplied gate text,
  not a port claim, so it is not itself a false green — but see below.

## Unfixed staleness, now three rounds old

`COMPONENT_PARITY.md:364` still says "394 of 394" where the live,
independently-confirmed number is 395/395 (451 combined). This was flagged
in round 5, flagged again in round 6 as "two rounds old," and is now
**three** rounds unfixed in this commit. It is not a false claim on its
own terms (394/394 was once true, at an earlier commit, for a smaller
check count) — but letting a wrong number sit in the project's own ledger
for a third consecutive round, when the fix is a one-line edit and the
right number is sitting in the same file's git history, crosses from
"stale" into "a finding nobody is acting on," which is itself the shape of
accountability drift. Recorded here explicitly, again, because repeating a
finding without escalating its description would itself be a form of
letting a gap be excused by habit.

## Verdict

No gap in this port is being excused rather than built. Every currently-
open gap (five, listed in `.reports/component-parity-round7.md`) is stated
plainly, with the binding limitation behind gap 3 documented with a real,
reproduced negative result (`current_button` stays 0) rather than asserted
untested. This round's green claims were independently re-executed, not
carried forward on a prior report's word, including the two claims most at
risk of being a false green (`rake data:install`, the fixed test command) —
both were re-run against fresh state and both held. One accountability
finding escalates this round: the "394 of 394" staleness in
`COMPONENT_PARITY.md` is now three rounds unfixed, trivial to fix, and
still not fixed. `clean: false` — five open component-parity gaps remain
(1, 3, 4, 5, 6 in this round's numbering), and the runtime gate itself is
genuinely green, independently reproduced in this session.
