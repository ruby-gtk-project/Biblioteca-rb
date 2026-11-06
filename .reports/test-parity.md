# Test parity — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `ced6a5b` |
| Upstream checks | **7** |
| Ported **and executed** | **2 / 7** |
| Ported but never executed | **2 / 7** |
| Gaps | **3 / 7** |
| Port's own checks, executed this round | 36 specs + 394 drive checks + 55 driver steps, **0 failures** |
| Audited | 2026-11-06 |

## Round 4 — re-run independently, not carried forward on trust

Every command in the table immediately below was re-run this round from
`ced6a5b`, the one commit since the last audit (it wires two unused gems,
`ashpd`/`libspelling`, per `FINDINGS.md` #10 — no test, driver or spec file
changed, and the counts are unchanged): `394 of 394` drive checks, `36
examples, 0 failures` under RSpec, `31 steps / 2 skipped` and `24 steps / 0
failures` on the two secondary drivers, `32 files inspected, no offenses
detected` under `rubocop`, and `rake data:validate` confirmed to still run
and validate nothing — `desktop-file-validate`, `appstreamcli`,
`appstream-util` and `flatpak-builder-lint` are all still **MISSING** from
the dev shell. Gaps 6 and 7 (the two `flatpak-builder-lint` checks) and T-1
through T-3 are unchanged and still open.

## Does the suite run? Yes — this round, all of it

Stated plainly because the previous edition of this file said the opposite
("`bundle exec rspec` — **does not run**", "Neither file has ever been run
under RSpec"). That is now false and is retracted. Every command below was run
in this session in the fork's dev shell:

| Command | Result |
|---|---|
| `nix develop --command xvfb-run -a ruby -e '…RSpec::Core::Runner.run…'` | `36 examples, 0 failures` |
| `nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_biblioteca.rb` | `394 of 394 checks passed` / `DRIVE OK` |
| `nix develop --command xvfb-run -a … ruby test/drive_app.rb` | `31 steps, 2 skipped, 0 failures` |
| `nix develop --command xvfb-run -a … ruby test/drive_sidebar.rb` | `24 steps, 0 failures` |
| `nix develop --command rubocop lib exe spec test po` | `32 files inspected, no offenses detected` |
| `nix develop --command rake schema:validate` | `glib-compile-schemas --strict --dry-run` → clean |
| `nix develop --command rake data:validate` | **ran, checked nothing** — see gaps 1 and 2 |

## Upstream's census, and why the script returns zero

`scripts/test-census.sh` returns an empty census for `origin/main`, which is
correct: there is no test tree, no `Test.add_func`, no `it(…)`, no
`def test_*`. The root `meson.build` has no `test()` call either. **But
`data/meson.build` has four**, at lines 10, 31, 38 and 52, and `make test` is
`make lint`, which is three more. A censusing step that trusts the script
alone reports 0 here every time. The honest figure is **7**.

## Suite: `data/meson.build` — installed-file validation (4 checks)

| # | Upstream check | Purpose | Port | State |
|---|---|---|---|---|
| 1 | `Validate desktop file` (`:10`) — `desktop-file-validate <configured .desktop>` | the desktop entry the shell reads parses and carries no invalid keys | `rake data:validate` — `rakelib/biblioteca.rake:127-129` | **ported, never executed** |
| 2 | `Validate metainfo file` (`:31`) — `appstreamcli validate --override=release-time-missing=info --no-net` | the AppStream metainfo software centres read is valid | `rake data:validate` — the *same* task, `:130-138` | **ported, never executed** |
| 3 | `Validate appstream file` (`:38`) — `appstream-util validate` | the second, stricter AppStream validator — the one Flathub gates on (`Makefile:43`) | — | **gap** |
| 4 | `Validate schema file` (`:52`) — `glib-compile-schemas --strict --dry-run` | the five settings keys exist at runtime | `rake schema:validate` — `rakelib/biblioteca.rake:48-56` | **ported and executed, passes** |

### Gap 1+2 — the false green, and it is this file's most serious finding

`rake data:validate` is written as:

```ruby
if system("which desktop-file-validate > /dev/null 2>&1")
  sh("desktop-file-validate", …)
end
if system("which appstreamcli > /dev/null 2>&1")
  sh("appstreamcli", "validate", …)
end
```

Neither tool is in the dev shell. Checked this round:

```
desktop-file-validate      MISSING
appstreamcli               MISSING
appstream-util             MISSING
flatpak-builder-lint       MISSING
glib-compile-schemas       /nix/store/…-glib-2.88.3-dev/bin/glib-compile-schemas
```

So the task runs, prints nothing, exits 0, and **nothing has ever validated
`data/app.desktop` or `data/app.metainfo.xml`.** The previous edition of this
file recorded row 1 as `ported` with a bare dash in the "owed" column; that
was a green resting on something never executed. It is withdrawn.

Fix, in order: add `desktop-file-utils` and `appstream` to the flake's
`devShells.default.packages`; split `data:validate` into
`data:validate:desktop`, `data:validate:metainfo` and
`data:validate:appstream` so one failure does not hide the next (today a
`desktop-file-validate` failure aborts before `appstreamcli` runs, so check 2
is lost even when the tool *is* present); make each task **fail** when its
tool is missing rather than skip, or at minimum print `SKIPPED: <tool> not
found` so a reader cannot mistake silence for a pass.

## Suite: `make test` → `make lint` (3 checks)

| # | Upstream check | Purpose | Port | State |
|---|---|---|---|---|
| 5 | `eslint --max-warnings=0 src` (`Makefile:14`) | the source tree is lint-clean at zero tolerance | RuboCop — `.rubocop.yml`, `.rubocop_rspec.yml`, 7 project cops in `cops/` | **ported and executed, passes** on `lib exe spec test po` (32 files, 0 offences) |
| 6 | `flatpak-builder-lint manifest --exceptions build-aux/app.drey.Biblioteca.json` (`:19`) | the release Flatpak manifest is valid | — | **gap** |
| 7 | same, `…Devel.json` (`:20`) | same, for the development profile the `devel` CSS class and `.Devel` app id exist for | — | **gap** |

Gaps 6 and 7 follow from `.reports/component-parity.md` gap 2: there is no
manifest for the check to run on. They stay counted here rather than excused.

Two caveats on row 5, neither of which makes it a gap:

* `bundle exec rubocop` **fails** — `can't find executable rubocop for gem
  rubocop … not currently included in the bundle` — although `Gemfile:66` has
  `gem "rubocop"`. The binary on `PATH` in the dev shell works. Anyone
  following the documented incantation gets an error.
* `rubocop` over the whole tree reports **98 offences in 89 files**, all in
  kettle-jem scaffolding (`gemfiles/modular/*.gemfile`, `Appraisals`), none in
  code this port wrote. `rake rubocop_gradual:check` — which the previous
  edition cited as the port's answer to check 5 — **does not exist**: it is
  absent from `rake -T`, and there is no `.rubocop_gradual.lock`.

## The port's own checks — and where they are not wired in

`spec/` (36 examples, 2 files) and `test/` (3 drivers, 449 assertions
between them) both pass. Three structural problems:

| # | Problem | Fix |
|---|---|---|
| T-1 | **`rake default` runs nothing.** `Rakefile:63` is `task :default do puts "Default task complete." end`. Upstream's seven checks are two commands (`meson test`, `make test`); the port has no single command that runs any of its own | make `default` depend on the specs, the three drivers, `rubocop`, `schema:validate` and the three split `data:validate` tasks |
| T-2 | **The 394 drive checks are in no CI.** `.gitlab-ci.yml` runs `bin/rspec spec` only, and its image has no GTK and no X server. So CI covers 36 examples over 2 of 19 `lib` files and nothing else. There is no `.github/workflows` at all | run `test/drive_biblioteca.rb` under `xvfb-run` in CI; it is the only thing that touches the other 17 files |
| T-3 | **17 of 19 `lib/*.rb` have no RSpec spec.** Only `lib/fzy.rb` and `lib/doc_index.rb` do. Window, sidebar, both views, the web view, the find overlay, the theme selector, the settings layer and the menu are covered *only* by the drive scripts, which T-2 keeps out of CI | the drive run is the right instrument for widgets; the fix is T-2, not 17 more spec files |

## Narrow checks found this round

A component a check only *looks at* is not exercised. Two:

| Where | What the check asserts | What it should assert |
|---|---|---|
| `test/drive_biblioteca.rb:1198-1199` | `SidebarMenu::BOOKMARKS.length == 8` and every value `start_with?("https://")` — i.e. it reads the Ruby hash | the live `Gio::Menu`: 8 items in the `Bookmarks` submenu, each with `action == "win.new-tab"` and a `target` equal to upstream's URL. The detailed-action spelling `win.new-tab('https://…')` is the part most likely to break and nothing touched it. **Verified by hand this round and it is correct** — the check is still the wrong check |
| `lib/theme_selector.rb#labelled_button` | nothing. `grep -n accessible test/*.rb` is empty | that the `<accessibility>` property name in `BUTTON_UI` is one GTK accepts. `Gtk::Builder` was shown this round to accept `<property name="no-such-prop">` silently, so a typo here is invisible. See `.reports/component-parity.md` gap 5 |

And one check that is narrow for a reason outside the port's control:
`test/drive_biblioteca.rb:404` covers `Sidebar` with `start_index == -1` only
over an **empty** `docs` array, where the clamp-to-zero in
`lib/sidebar.rb#start_index` cannot be observed. That clamp is
`.reports/component-parity.md` gap 6 and wants a check with non-empty docs and
no `Gtk-4.0` node.

## Environment limits the drive run names rather than papers over

Carried forward from `.reports/drive.md` because they bound what "394 passed"
means: there is no window manager under Xvfb, so `Gtk::Window#maximized` is
never true and the `window-maximized` binding is driven through a
`Gtk::ToggleButton` on the same `Settings#bind` path; `has_focus?` is never
true, so focus is asserted through the window's `focus_widget`; and the screen
must be at least 1200×900 or the `max-width: 850sp` breakpoint is applied for
the whole run — the script asserts the screen size as its second check.
