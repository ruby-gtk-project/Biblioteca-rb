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

Updated this round: this is no longer true. `rspec` (from the Nix devshell's
`pkgs.rubyPackages_3_4.rspec`) runs the full suite under the real runner —
`spec/doc_index_spec.rb`, `spec/fzy_spec.rb` and the new
`spec/translation_spec.rb` (see TRANSLATION_PARITY.md TP-2) — and it passes:
**38 examples, 0 failures**, replayed on this checkout with
`nix develop --command ruby -e 'require "rspec/core"; exit
RSpec::Core::Runner.run(["--format", "progress", "--require", "spec_helper",
"spec"])'`. The `around` / `be_within` / `:extra` plumbing every one of those
specs relies on has therefore been exercised, not just read.

`rake default` (`rakelib/default.rake`) now wires this suite, RuboCop (when a
RuboCop that actually resolves against this gemset is on `PATH` — it skips
loudly otherwise, rather than silently succeeding against the wrong bundle),
`rake schema:validate`, `rake gettext:check_pot_drift` (TP-1) and all three
headless UI drivers (`test/drive_app.rb`, `test/drive_sidebar.rb`,
`test/drive_biblioteca.rb`) into one task, run end to end under
`xvfb-run -a -s '-screen 0 1600x1200x24' rake default`. A CI workflow
(`.github/workflows/ci.yml`) runs exactly that on every push to `ruby` and
every pull request — there was no workflow of any kind checked in before this
round.

`rake data:validate` is fixed in the same round: `desktop-file-utils`,
`appstream` and `appstream-glib` (`appstream-util`, the stricter Flathub
validator — see `.reports/test-parity.md`'s gap 3) are now in the Nix devshell
(`flake.nix`), so the task no longer runs and validates nothing. Running it
for the first time found a real bug —
`desktop-file-validate`'s `DBusActivatable=true` check reads the reverse-DNS
id out of the *filename*, and `data/app.desktop` is named generically pending
the id substitution `rake data:install` does — fixed by validating a
throwaway copy under the installed basename instead of the raw file
(`rakelib/biblioteca.rake`). `rake data:validate` now runs `appstream-util
validate` too (test-parity gap 3, previously no port counterpart at all), and
both AppStream validators fail — `appstreamcli` on
`data/app.metainfo.xml`'s `date="2026-09-xx"` release-date placeholder,
`appstream-util` on the screenshot's padding, the `<ul>`-first description,
the thin `<p>` count and the unspecified release timestamp — all of it
byte-for-byte upstream's own content (`git show
origin/main:data/app.metainfo.xml`), not something this port introduced
(FINDINGS.md #12). Not "fixed" by diverging from upstream's text, and not
wired into `rake default` for that reason — `rake data:validate` is run on
its own, and its exit code is accurate rather than always-zero.

## Still owed

1. `spec/browse_view_spec.rb` — `BrowseView#item_index` is the tree-path
   arithmetic that turns "the web view is showing this uri" into "select this
   row", and it is the most intricate pure method in the port. It walks a
   `Gtk::TreeListModel`, so a spec for it needs the `gtk4` gem at load time —
   doable now that the suite runs under a real GTK process via the devshell,
   but not written this round.
2. `spec/search_view_spec.rb` — `QUERY_TYPES` / `QUERY_PATTERN` prefix parsing
   and the smart-case rule. `lib/search_view.rb` requires `adwaita` at load
   time, so the same applies; not written this round.
3. `rake data:validate`'s AppStream findings above (FINDINGS.md #12):
   upstream's own content has not been reported upstream.
4. `flatpak-builder-lint` on the manifests — still no port counterpart
   because no manifest exists (COMPONENT_PARITY.md gap 2).
