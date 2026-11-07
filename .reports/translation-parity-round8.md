# Translation parity — round 8

Date: 2026-11-07. Port commit audited: `781d5f1`. No `po/`/`locale/` diff
since round 5 (`git diff --stat 7dfed31 HEAD -- po locale`, empty).

## Upstream ships zero msgids (re-confirmed)

```
git ls-tree -r --name-only origin/main | grep -E '^po/'
```

Still empty. No upstream msgid floor exists for this port to fall short
of.

## Re-counting the port's own catalogue, independently this round

```
grep -c '^msgid' po/org.rubygtkproject.Biblioteca.pot   -> 65  (64 real + 1 header)
grep -c '^msgid' po/fr.po                                -> 65  (64 real + 1 header)
```

Matches rounds 5-7's 64/64 exactly, re-derived fresh rather than quoted.

## `.mo` resolution, re-run live this round

`spec/translation_spec.rb` ran as part of this round's full RSpec run
(38 examples, 0 failures — see `.reports/test-parity-round8.md`) and
compiles `po/fr.po` to a real `.mo`, resolving all 64 messages through
`GetText`.

## Verdict

No translation-parity gap. 64/64 msgids survive into `fr.po` with
non-empty translations, re-confirmed by direct count and a passing spec
run fresh this round. Unchanged from rounds 5-7.
