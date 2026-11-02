# Test parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` |
| Source of the gap list | `.reports/test-parity.md` (audited at `7211c78`) |
| Upstream tests | **0** |
| Upstream tests ported | 0 / 0 |
| Extra (non-parity) specs in the port | 2 files |
| Test command | `bundle exec rspec` |

Parity is 0 / 0 and met: upstream has no test suite. `meson.build` has no
`test()` call, there is no test tree on `origin/main`, and the `Makefile`'s
`test` target is `make lint`. The port inherits no safety net and owes itself
one.

## What landed this round

### `lib/biblioteca/rb.rb`

`spec/spec_helper.rb:25` requires `"biblioteca/rb"`, which did not exist, so
the helper raised `LoadError` and **no spec in this repository could run at
all** — including a spec that passed. The file now exists and requires the
version and the application object without running anything.

### `spec/fzy_spec.rb`

`lib/fzy.rb` is a port of `src/sidebar/fzy.js`, and it is the one file in the
port whose output is a number that has to match upstream's exactly: it decides
the order of every search result. The spec pins:

* `SCORE_MIN` for an empty needle, an empty haystack, and a haystack longer
  than `MAX_HAYSTACK`; `SCORE_MAX` when the needle is the whole haystack;
* `.match?` as an exact, case-sensitive subsequence test — the case folding is
  the caller's, under SearchView's smart-case rule;
* each bonus separately, as an exact number: the leading-slash bonus (0.9), the
  consecutive-match bonus (1.0), the word bonus after `_` (0.8), the camel-case
  bonus, and the inner (-0.01) and trailing (-0.005) gap charges;
* the ranking those add up to: `gtk_widget_show` above `gtk_widget_get_show`
  for the needle `gtkwidgetshow`, which is the behaviour a user notices.

### `spec/doc_index_spec.rb`

`lib/doc_index.rb` is a port of `build-aux/build-index.js` and is pure
computation over a gi-docgen `index.json`. The spec builds a fixture tree in a
temporary directory and pins the three mappings per symbol kind that the
sidebar and the search both depend on:

* the page each of the 19 symbol kinds links to, including the irregular ones
  (`class_method` is qualified by `struct_for` and not `type_name`, `content`
  carries its own `href`);
* the tag shown as a pill beside a search result: the eight kinds that are
  relabelled and the eleven that pass through;
* the name the search matches against: `ctype` for types, `ident` for
  callables, and the `GtkWidget:prop` / `GtkWidget::signal` /
  `GtkWidget.vfunc` spellings for members;
* `IGNORED_LIBRARIES`, a directory with no `index.json`, the section and
  subsection sort order, the subsection nesting under the `REQUIRED` types,
  `#start_index` returning `-1` when there are no GTK docs, and the
  `#write` / `.read` round trip through `doc-index.json`.

Both files are tagged `:extra` — they are not parity tests, because there is
nothing upstream to be at parity with.

## Verification status

**The specs have not been run under RSpec.** `bundle exec rspec` reports
`command not found: rspec`: neither `rspec` nor `kettle-test` is installed in
this checkout, and `bundle install` needs the network. `ruby -c` passes on
both files.

Every expectation in both files was derived from the implementation's actual
output rather than written from the source by eye, and then checked: all 20
`doc_index_spec.rb` expectations were replayed outside RSpec, against the same
fixture, and all 20 matched; the `fzy_spec.rb` numbers are `Fzy.score`'s own
output for those inputs.

That is still not a green suite. A spec nobody has run under its runner is a
claim about the runner as well as about the code, and the `around` /
`be_within` / `:extra` plumbing has not been exercised.

## Still owed

1. Run them. `bundle install`, then `bundle exec rspec`.
2. `spec/browse_view_spec.rb` — `BrowseView#item_index` is the tree-path
   arithmetic that turns "the web view is showing this uri" into "select this
   row", and it is the most intricate pure method in the port. It walks a
   `Gtk::TreeListModel`, so a spec for it needs the `gtk4` gem at load time;
   not written this round.
3. `spec/search_view_spec.rb` — `QUERY_TYPES` / `QUERY_PATTERN` prefix parsing
   and the smart-case rule. `lib/search_view.rb` requires `adwaita` at load
   time, so the same applies; not written this round.
