# Translation parity — round 7

Date: 2026-11-07. No `po/`/`locale/` diff since round 5
(`git diff --stat 828bdd5 HEAD -- po locale`, empty).

## Upstream ships zero msgids (re-confirmed)

```
git ls-tree -r --name-only origin/main | grep -E '^po/'
```

Empty — `origin/main` has no `po/` directory, no `LINGUAS`, no `.po` file.
Upstream's own source carries bare `_("…")` calls in `.blp`/`.js` with no
extraction pipeline wired into its build. There is no upstream msgid floor
for this port to fall short of; everything in `po/` is the port's own
addition, not a parity obligation.

## Re-counting the port's own catalogue, independently this round

```
grep -c '^msgid' po/org.rubygtkproject.Biblioteca.pot   -> 65  (64 real + 1 header)
grep -c '^msgid' po/fr.po                                -> 65  (64 real + 1 header)
grep -c '^msgstr ""' po/fr.po                             -> 1   (header only)
```

Matches round 5 and round 6's 64/64 exactly, re-derived rather than
quoted. Every real msgid the port's own `po/extract.rb` produces has a
non-empty `fr.po` translation; none dropped between `.pot` and `.po`.

## `.mo` resolution, re-run live this round

`spec/translation_spec.rb` ran as part of this round's full RSpec run
(see `.reports/test-parity-round7.md`: 38 examples, 0 failures) and
compiles `po/fr.po` to a real `.mo`, resolving all 64 messages through
`GetText`. Re-executed this round, not assumed from the prior report.

## Verdict

No translation-parity gap. 64/64 msgids survive into `fr.po` with
non-empty translations, confirmed by direct re-count and by a passing spec
exercising the compiled catalogue, both run fresh this round. Unchanged
from round 5 and round 6.
