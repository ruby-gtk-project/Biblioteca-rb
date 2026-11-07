# Component identification — round 8

Date: 2026-11-07. Port commit audited: `781d5f1` ("Drive the sidebar
middle-click gesture with real X11 events; port Flatpak manifests; fix
stale drive-check count").

## Diff since round 7's `7dfed31`

```
git diff --stat 7dfed31 HEAD -- lib exe test spec po data rakelib
```

No `lib/`, `spec/`, `po/`, or `data/` change. The diff is confined to:
`COMPONENT_PARITY.md` (ledger text), `flake.nix` (+xdotool), `rakelib/
default.rake` (+`drive:middle_click`), `test/drive_middle_click.rb` (new,
259 lines), and six new `build-aux/*.json` files (Flatpak manifest +
module pins). No new `lib/` component class was added; `test/
drive_middle_click.rb` is a test driver, not an application component.

## Re-derivation of the component count

```
find lib exe -type f | sort   -> 21 files (unchanged)
```

Still 19 `lib/*.rb` + `lib/biblioteca/*.rb` component files, plus the two
non-component gem-scaffolding files (`lib/biblioteca/rb.rb`, `lib/
biblioteca/rb/version.rb`), plus `exe/biblioteca`. Unchanged from rounds
3-7. The task's gate text still says "21 components," which now matches
the raw `lib`+`exe` file count (21) exactly for the first time in this
audit's history, though the port's own ledgers (`PORTING.md`, `COMPONENT_
PARITY.md`) still describe 19 *application* components (excluding the two
gem-scaffolding files) — a difference in what is counted, not a
discrepancy either side has reason to fix.

## New non-`lib/` surface: the Flatpak manifest

`build-aux/org.rubygtkproject.Biblioteca.json` and `.Devel.json`, plus six
`build-aux/modules/*.json`, are new this round. They map to upstream's
`build-aux/app.drey.Biblioteca.json`, `build-aux/app.drey.Biblioteca.Devel.
json`, and `build-aux/modules/*.json` — the "Not started" row round 5-7
all carried in `PORTING.md`. This is not a `lib/` component; it is
packaging, identified and tracked separately in `.reports/component-
parity-round8.md`.

## Verdict

No new application component surfaced, none dropped. Identification is
unchanged from round 7: 19 `lib/` components + `exe/biblioteca`. The only
new identified surface this round is packaging (the Flatpak manifest),
which is evaluated for completeness in the parity report, not here.
