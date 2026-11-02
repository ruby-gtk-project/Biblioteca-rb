# Porting Biblioteca to Ruby

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` — GJS, blueprint, GTK 4, libadwaita 1, WebKitGTK 6.0 |
| Port | this branch, `ruby` |
| Ledgers | `COMPONENT_PARITY.md`, `TRANSLATION_PARITY.md`, `TEST_PARITY.md`, `FINDINGS.md` |

Upstream is the spec. This file records how the port is laid out, what it
deliberately does differently, and where to look for what is still owed.

## Layout

One upstream source file maps to one file under `lib/`; the map is at the top
of `lib/biblioteca.rb`. Upstream's `data/` tree and its `src/icons/` are
`data/` here. `data/ui/shortcuts.ui` is the one blueprint that stayed markup
rather than becoming Ruby.

```
exe/biblioteca            the launcher — one expression
lib/biblioteca.rb         the file map; requires the application
lib/biblioteca/application.rb
lib/package.rb            src/bin.js's `pkg`: app id, domain, data dirs
lib/*.rb                  one per upstream source file
data/app.*                upstream's data/, with @app_id@ substituted
data/icons/               upstream's data/icons/ + src/icons/
data/ui/shortcuts.ui      src/Shortcuts.blp
po/                       POTFILES.in, extract.rb, the .pot
rakelib/biblioteca.rake   data/meson.build's install and validate steps
spec/                     extra (non-parity) specs — see TEST_PARITY.md
```

## The identity chain

Upstream threads one value, meson's `app_id`, through the binary name, the
GResource prefix, the GSettings schema id and path, the gettext domain, the
icon name and the `.desktop`, `.service` and `.metainfo.xml` basenames.

Here that value is `Package::BASE_APP_ID` = `org.rubygtkproject.Biblioteca`,
and everything else is derived from it in `lib/package.rb`:

| Derived | From |
|---|---|
| application id | `Package.app_id` — `.Devel` appended when `BIBLIOTECA_DEVEL` is set |
| icon name | `Package.icon_name` |
| GSettings schema id / path | `Package.schema_id`, `Package.schema_path` |
| gettext domain | `Package::DOMAIN` |
| `.desktop`/`.service`/`.metainfo.xml` basenames | `rakelib/biblioteca.rake`'s `APP_ID` |

The id is the port's own, not `app.drey.Biblioteca`, so that running this does
not collide on the session bus with an installed copy of the original. Change
`BASE_APP_ID` and the four `data/*.xml`/`*.desktop`/`*.service` files and the
icon filenames all have to move with it; `data/app.gschema.xml` hardcodes the
same string, which is what makes a mismatch show up as a schema lookup failure
rather than as silently reading another app's keys.

## Deliberate divergences

Three, and only three, with the reason in the file that has them:

1. **Every per-tab handler is guarded on the view that emitted it.** Upstream
   writes the *selected* view's chrome from *any* tab's handler, so a
   background tab's load moves the foreground progress bar. This port guards
   on `view.equal?(webview)`. Upstream has a bug; `FINDINGS.md` #5 describes it
   and how to see it. **The report upstream is still owed.**
2. **The gettext domain is the release id for both profiles.** Upstream's
   `pkg.initGettext()` binds `pkg.name`, which orphans a Devel build's
   catalogue. `FINDINGS.md` #6.
3. **No Flatpak guard.** `src/bin.js:27-32` exits unless
   `Xdp.Portal.running_under_flatpak()`. This port is a gem; there is no
   sandbox to require, and the documentation root is found rather than assumed
   (`DocIndex::DEFAULT_ROOTS`). Recorded at the top of `lib/package.rb`
   alongside the other two pieces of upstream setup that have no counterpart
   (`resource_base_path`, the `LANG=en_US.UTF-8` launcher wrapper).

Everything else that differs is a binding limitation, and those live in
`FINDINGS.md` with a reproduction — never in the comment that describes the
behaviour, which states only what the port does.

## House style

`.claude/skills/ruby-gtk` is the contract: widgets are memoized methods,
configuration lives in the method's `tap`, assembly happens only in `build`,
no `return`, no modifier `if`, no conditional assignment. `.rubocop.yml` plus
the custom cops in `cops/` enforce the rest. `bundle exec rubocop` before
committing.

Two binding facts that are easy to get wrong and are worth repeating here:
the namespace is `Adwaita::`, not `Adw::`; and `Adwaita::Application` is
broken, so the application object is a `Gtk::Application` while the window is
an `Adwaita::ApplicationWindow`.

## Running it

```sh
direnv allow          # or: nix develop
bundle install
rake schema:compile   # so Settings uses Gio::Settings, not the JSON fallback
bundle exec ruby -Ilib exe/biblioteca
```

`rake data:install` installs the desktop entry, metainfo, D-Bus service,
schema and icons under `PREFIX` (default `~/.local`), which is what makes the
app appear in the shell. Without it the app still runs from a checkout:
`Package.data_dir` falls back to the repository's own `data/`.

## What is owed

`COMPONENT_PARITY.md` and `TEST_PARITY.md` each end with a "still owed" list.
The three largest items, as of this round:

1. **Nothing has been run.** The `gtk4`, `adwaita`, `webkit-gtk` and `gettext`
   gems are not installed in this checkout, so no widget in this port has been
   drawn and no spec has gone green. Every parity claim is a reading of the
   upstream source and of the bindings' own source and GIR.
2. The two upstream bug reports (`FINDINGS.md` #5 and #6).
3. `spec/browse_view_spec.rb` and `spec/search_view_spec.rb` — the tree-path
   arithmetic and the query-prefix parsing, both of which need the GTK gems at
   load time.
