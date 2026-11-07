# Translation parity — Biblioteca-rb — round 5 (verification pass)

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `828bdd5` |
| Upstream messages | 0 (upstream ships no `po/`) |
| Port catalogue | `po/org.rubygtkproject.Biblioteca.pot`, **65** `msgid` lines |
| Languages in the port | 1 (`fr`) |
| Audited | 2026-11-07 |

## Re-confirming upstream ships no catalogue

```
git ls-tree -r --name-only origin/main | grep -i '^po/'   # empty
git show origin/main:src/biblioteca | grep -i LANG         # forces LANG=en_US.UTF-8, "We do not support translations"
```

Both checks reproduce `TRANSLATION_PARITY.md`'s existing claim: there is no
donated catalogue to carry across, and the port's `po/` tree is net-new work
the port owes itself, not a parity floor set by upstream.

## Re-counting the port's own catalogue

```
grep -c '^msgid' po/org.rubygtkproject.Biblioteca.pot   # 65  (64 real + 1 empty header)
grep -c '^msgid' po/fr.po                                # 65  (64 real + 1 empty header)
grep -c '^msgstr ""' po/fr.po                            # 1   (only the header; every real msgid has a non-empty msgstr)
```

64 real, translatable messages, all 64 present in `fr.po` with a non-empty
translation — matches `TRANSLATION_PARITY.md`'s claim of a "complete
64/64-message French catalogue" exactly; this is not taken on the ledger's
word, it is recounted from the files directly.

`TRANSLATION_PARITY.md` separately claims 61 of those 64 keys are
byte-identical to msgids this port's own source produces from upstream
strings (the other 3 are `ThemeSelector`'s, vendored from `troll`, which is a
real upstream file but not part of `origin/main`'s own `po/`-eligible
surface — there being no `po/`-eligible surface at all). That 61/64-vs-3
split was not re-derived from scratch this round (it is a correspondence
mapping, not a count that drifts on its own), but the total (64) and the
French completeness (64/64) were re-measured directly above and match.

## Re-confirming the `.mo` actually resolves translations, not just that the files parse

`spec/translation_spec.rb` (new since round 4, per the commit message) is
part of the 38-example RSpec run re-executed this round (see
`.reports/test-parity-round5.md`) and passed. It compiles `po/fr.po` to a
real `.mo` and resolves all 64 messages through `GetText`, which is the thing
that actually proves a catalogue works — a `.po` file that merely parses can
still fail to compile or fail to bind to the right domain.

## Verdict

No translation-parity gap found this round. Upstream genuinely ships zero
languages and zero msgids, so there is no floor the port could fall short
of; the port's own extraction (64 real strings, marked, re-counted directly
from the `.pot`) and its own French catalogue (64/64, re-counted directly and
proven against a compiled `.mo` by a passing spec) both check out
independently of the prior round's report.
