# Translation parity — round 6

Date: 2026-11-07. No `po/` diff since round 5 (`git diff --stat 828bdd5
HEAD -- po locale`, empty).

## Upstream ships zero msgids (re-confirmed)

`git ls-tree -r --name-only origin/main | grep -E '^po/'` was re-run this
round: empty — upstream has no `po/` directory and ships no translations
at all. There is no upstream floor for this port to fall short of.

## Re-counting the port's own catalogue directly (not quoted from round 5)

```
grep -c '^msgid' po/org.rubygtkproject.Biblioteca.pot   -> 65  (64 real + 1 header)
grep -c '^msgid' po/fr.po                                -> 65  (64 real + 1 header)
grep -c '^msgstr ""' po/fr.po                             -> 1   (only the header)
```

Re-derived independently this round, matches round 5's 64/64 exactly.
Every real, translatable msgid the port's own extraction produces has a
non-empty French translation; none dropped.

## `.mo` resolution, re-run live

`spec/translation_spec.rb` was included in this round's RSpec run (see
`.reports/test-parity-round6.md`, 38 examples / 0 failures) and compiles
`po/fr.po` to a real `.mo`, resolving all 64 messages through `GetText` —
re-executed, not assumed.

## Verdict

No translation-parity gap. 64/64 msgids survive into `fr.po` with non-empty
translations, re-verified by direct count and by a passing spec that
exercises the compiled `.mo`, both independently this round. Unchanged from
round 5.
