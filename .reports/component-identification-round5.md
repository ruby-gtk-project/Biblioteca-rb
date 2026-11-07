# Component identification — Biblioteca-rb — round 5

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` @ `828bdd5` |
| Port units | 19 `lib/*.rb` files + `data/ui/shortcuts.ui` (unchanged from the round-4 census in `.reports/component-identification.md`) |
| Audited | 2026-11-07 |

This round re-verifies the round-4 unit list rather than re-deriving it from
scratch: `git diff ced6a5b..828bdd5 --stat` touches no file under `lib/`
except `lib/sidebar.rb` (the `-1` clamp) and `lib/package.rb` (the comment
rewrite), adds `vendor/troll/` (a vendored submodule, not a new port unit —
it is the upstream source `ThemeSelector`/`WindowState` were already ported
from, now readable instead of an unresolved gitlink), and adds `po/fr.po`
(a catalogue, not a component). `lib/` still has exactly 19 files:

```
about_dialog.rb      doc_index.rb          settings.rb
biblioteca.rb         documentation_page.rb shortcuts_window.rb
biblioteca/application.rb find_overlay.rb  sidebar.rb
biblioteca/rb.rb      fzy.rb                 sidebar_menu.rb
browse_view.rb        package.rb             style.rb
                                               theme_selector.rb
                                               web_view.rb
                                               window.rb
                                               window_state.rb
                                               zoom_buttons.rb
```

19 top-level component files + the `biblioteca/` namespace pair
(`application.rb`, `rb.rb`) that hold the `Adw.Application` subclass and the
version constant — matching the unit count `drive.md`/`COMPONENT_PARITY.md`
have used since round 3 and confirmed live by `test/drive_biblioteca.rb`'s
own component table.

No new upstream file appeared on `origin/main` since `9e4eded` (`git log
origin/main -1` is still that sha), so there is no new unit to identify this
round. Nothing in this section changes the round-4 inventory; it is kept
current by confirming the diff between `ced6a5b` and `828bdd5` added no
widget, removed no widget, and renamed nothing.

See `.reports/component-identification.md` for the full per-file widget / CSS
/ signal / action tables — they are unchanged and still accurate against the
current tree, verified by grepping each widget-constructor line named there
against `lib/*.rb` at `828bdd5`.
