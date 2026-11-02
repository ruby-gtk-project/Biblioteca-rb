# Test parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4ededb8dff1b537de09d25ce2e55d1997c43d3` (`9e4eded`) |
| Port | `ruby` @ `d63ee497e572c2d5ef7ab7790ef119be3371f9ed` (`d63ee49`) |
| Upstream checks | **7** |
| Ported | **3 / 7** |
| Gaps | **4** |
| Extra (non-parity) specs in the port | 36, in 2 files |
| Test command (port) | `bundle exec rspec` — **does not run** (`command not found: rspec`) |
| Audited | 2026-11-02 |

## The port's own ledger is wrong about this

`TEST_PARITY.md` on `ruby` opens:

> | Upstream tests | **0** |
> Parity is 0 / 0 and met: upstream has no test suite. `meson.build` has no
> `test()` call, there is no test tree on `origin/main`, and the `Makefile`'s
> `test` target is `make lint`.

The root `meson.build` has no `test()` call. **`data/meson.build` has four**,
at lines 10, 31, 38 and 52. The ledger checked one build file, concluded zero,
and wrote "parity is met" over four real upstream checks. `make test` is
`make lint`, which is three more. So the honest figure is 7 upstream checks,
not 0, and the parity claim in `TEST_PARITY.md` has to be withdrawn.

`scripts/test-census.sh` returns an empty census for the upstream tree, which
is correct and is exactly why the skill says to cross-check it against the
build file's test list. The script looks for `Test.add_func`, `it(...)`,
`#[test]`, `def test_*` and friends; it does not look for meson `test()`
entries that invoke an external validator. A censusing step that trusts the
script alone reports 0 here, every time.

## Suite: `data/meson.build` — installed-file validation (4 checks)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 1 | `Validate desktop file` (`data/meson.build:10`) — `desktop-file-validate <configured .desktop>` | the desktop entry the shell reads parses and carries no invalid keys, so the app appears in the launcher | `rake data:validate` — `rakelib/biblioteca.rake:131-133` | ported | — |
| 2 | `Validate metainfo file` (`data/meson.build:31`) — `appstreamcli validate --override=release-time-missing=info --no-net <configured metainfo>` | the AppStream metainfo software centres read is valid, so the app has a store listing | `rake data:validate` — the **same** task, `rakelib/biblioteca.rake:134-142` | **gap** | One named, separately runnable check for the metainfo, so a failure says which file is wrong. One task covering two upstream checks is not a bijection: a `desktop-file-validate` failure aborts the task before `appstreamcli` runs, and the metainfo is then never validated at all |
| 3 | `Validate appstream file` (`data/meson.build:38`) — `appstream-util validate <configured metainfo>` | the *second*, stricter AppStream validator — the one Flathub actually gates on (`Makefile:43`) | — | **gap** | The metainfo passes the validator Flathub runs, not only the one `appstreamcli` runs. The two disagree; upstream runs both on purpose |
| 4 | `Validate schema file` (`data/meson.build:52`) — `glib-compile-schemas --strict --dry-run` | the GSettings schema compiles with no warnings, so the five settings keys exist at runtime | `rake schema:validate` — `rakelib/biblioteca.rake:48-56` | ported | — |

## Suite: `make test` → `make lint` (3 checks)

| # | Upstream test | Purpose | Port test | State | Behaviour still owed |
|---|---|---|---|---|---|
| 5 | `eslint --max-warnings=0 src` (`Makefile:14`) | the whole source tree is lint-clean at zero tolerance | RuboCop: `.rubocop.yml`, `.rubocop_rspec.yml`, 7 project cops in `cops/`, `rake rubocop_gradual:check` | ported | — |
| 6 | `flatpak-builder-lint manifest --exceptions build-aux/app.drey.Biblioteca.json` (`Makefile:19`) | the release Flatpak manifest is valid, so the app can be built and published the one way upstream ships it | — | **gap** | There is a release manifest to lint. See `.reports/component-parity.md` gap 3 — the port ships no Flatpak manifest at all, so there is nothing for this check to run on |
| 7 | `flatpak-builder-lint manifest --exceptions build-aux/app.drey.Biblioteca.Devel.json` (`Makefile:20`) | same, for the development profile the `devel` CSS class and the `.Devel` app id exist for | — | **gap** | Same |

## Two things that make the three `ported` rows thinner than they read

**None of them runs under the port's declared test command.** `bundle exec
rspec` runs `spec/`. `rake data:validate`, `rake schema:validate` and
`rake rubocop_gradual:check` are separate targets that no aggregate task
invokes, so a green suite says nothing about any of them. Upstream's four are
`meson test` entries and its three are `make test`; both are one command.
Fix: make `rake default` depend on all of them.

**`rake rubocop_gradual:check` cannot pass as shipped.** There is no
`.rubocop_gradual.lock` in the tree (checked). The task checks the lock file
against the current offences; with no lock there is nothing to check against.

## Extra — specs written for the port, at parity with nothing

These are outside the count by definition. They are also the only automated
checks in the repository that assert anything about behaviour.

* `spec/fzy_spec.rb` — 16 examples over `lib/fzy.rb`, the port of
  `src/sidebar/fzy.js`. The bonuses and gap charges as exact numbers
  (`SCORE_MATCH_SLASH` 0.9, `_WORD` 0.8, `_CONSECUTIVE` 1.0, `GAP_INNER`
  -0.01, `GAP_TRAILING` -0.005), `SCORE_MIN`/`SCORE_MAX` at the boundaries,
  the `m > 1024` cutoff (`MAX_HAYSTACK`, matching `src/sidebar/fzy.js:109`),
  and the ranking `gtk_widget_show` above `gtk_widget_get_show`.
* `spec/doc_index_spec.rb` — 20 examples over `lib/doc_index.rb`, the port of
  `build-aux/build-index.js`. Per-kind link, tag and search-name mappings
  including the irregular ones (`class_method` qualified by `struct_for`,
  `content` carrying its own `href`), `IGNORED_LIBRARIES`, a directory with no
  `index.json`, section and subsection ordering, `REQUIRED` nesting,
  `#start_index` returning `-1`, and the `doc-index.json` round trip.

**Neither file has ever been run under RSpec.** `bundle exec rspec` reports
`bundler: command not found: rspec`; `ruby -e 'require "gtk4"'` raises
`LoadError`. `TEST_PARITY.md` says the same and says the expectations were
replayed outside RSpec instead. That is better than nothing and it is not a
green suite: the `around` hooks, the `be_within` matchers, the `:extra` tag
filtering and `spec_helper.rb`'s `require "biblioteca/rb"` are all unexercised.

So the port's automated-check position is: **36 specs that have never run, 3
of 7 upstream checks ported, none of the 3 wired into the test command.** The
19 `lib/*.rb` files holding the actual UI — window, sidebar, both views, the
web view, the find overlay, the theme selector, the settings layer — have no
test of any kind, upstream or extra, and cannot get one in this checkout
because the `gtk4` gem is missing.
