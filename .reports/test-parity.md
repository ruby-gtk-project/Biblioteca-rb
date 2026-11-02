# Test parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `7211c78` |
| Upstream tests | **0** |
| Ported | 0 |
| Gaps | 0 |
| Test command | `bundle exec rspec` (declared; see below — it does not run) |

Upstream has no test suite. Verified:

```
$ .claude/skills/test-parity/scripts/test-census.sh <upstream> | wc -l
0
```

and by hand: no `test/` or `tests/` directory on `origin/main`
(`git ls-tree -r --name-only origin/main` is 75 paths, none under a test tree),
no `def test_*`, no `unittest`, no `pytest`, no `#[test]`, no `#[cfg(test)]`,
no `Test.add_func`, no Jasmine `it(...)`, no `.spec.js`. The build files
confirm it: `meson.build` has no `test()` call at all, and the `Makefile`'s
test target is

```make
test: lint
```

where `lint` is eslint plus two flatpak-builder-lint invocations
(`Makefile:12-24`). `package.json` declares one script, `prepare: husky install`.

**Parity is therefore 0/0 and is met trivially.**

**The port inherits no safety net.** That is the finding of this ledger and it
is not a pass. Nothing upstream wrote down is owed, and nothing upstream wrote
down protects the 3,563 lines the port has written, which include at least four
bodies of logic that are pure computation and would be cheap to pin and are
pinned by nothing:

| Logic | Port | Why it wants a test |
|---|---|---|
| fzy scoring and the match test | `lib/fzy.rb` (141 lines) | 9 constants, a DP recurrence and a bonus table transliterated from JS. One transposed index silently reorders every search result and nothing fails. |
| `doc-index.json` construction | `lib/doc_index.rb` (336 lines) | 12 section types, 9 subsection types, 19 symbol-kind→URL mappings, a case-folding comparator standing in for `localeCompare`. Every URL in the sidebar comes from here. |
| tree path → flat index | `lib/browse_view.rb#item_index` | The arithmetic that turns "the webview is at this URI" into "select this row", with an expanded-descendant skip counter. Off by one and the sidebar selects the wrong symbol. |
| query prefix parsing and ranking | `lib/search_view.rb#rank`, `#query_for`, `#split_query` | 19 `QUERY_TYPES`, fzy's smart-case rule, whitespace stripping. |

## The port has no runnable suite

Worse than empty. `spec/` contains `README.md` and `spec_helper.rb` and no
example files, and `spec/spec_helper.rb:25` is

```ruby
require "biblioteca/rb"
```

There is no `lib/biblioteca/rb.rb` — `lib/biblioteca/` holds `application.rb`
and `rb/version.rb` only. So the helper raises `LoadError` and the suite cannot
load even to report zero examples. The gemspec, `.rspec`, `.simplecov`,
`Appraisals`, the 9 modular gemfiles and the Rakefile's test aggregation are all
scaffolding around a suite that does not exist and could not start.

## Extra

None. There is nothing to list.
