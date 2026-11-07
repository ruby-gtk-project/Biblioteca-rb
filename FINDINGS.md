# Findings — Biblioteca-rb

| | |
|---|---|
| Upstream | `origin/main` @ `9e4eded` |
| Port | `ruby` |
| Bindings | `gtk4` / `adwaita` / `webkit-gtk` 4.3.9, GTK 4.22, libadwaita 1.9 |

Binding defects and upstream bugs found while porting. Nothing in here excuses
a gap: a gap is recorded in `COMPONENT_PARITY.md` and in the code that has it.
This file is where the *cause* lives, with a reproduction, so that the code
comment can state only what the port does.

---

## 1. `GtkCustomSortFunc` reaches Ruby as a pair of addresses

**Where it bit:** `lib/search_view.rb`. Upstream's model chain is
`Gio.ListStore -> Gtk.FilterListModel -> Gtk.SortListModel -> Gtk.SingleSelection`
(`src/sidebar/SearchView.js`), with a `Gtk.CustomSorter` comparing a `score`
property the filter sets as a side effect.

**What happens:** `GtkCustomSortFunc` is declared
`int (*)(gconstpointer a, gconstpointer b, gpointer user_data)`. `gconstpointer`
carries no type, so the introspection loader has nothing to marshal and the
Ruby block is handed two integers — the raw addresses of the two items — rather
than the two `DocumentationPage` objects. There is no way back from an address
to the Ruby wrapper, so the comparison cannot be written.

**Reproduction:**

```ruby
require 'gtk4'
store = Gio::ListStore.new(Gtk::StringObject)
store.append(Gtk::StringObject.new('b'))
store.append(Gtk::StringObject.new('a'))
sorter = Gtk::CustomSorter.new { |a, b| p [a.class, b.class]; 0 }
Gtk::SortListModel.new(store, sorter).n_items
# => prints [Integer, Integer], not [Gtk::StringObject, Gtk::StringObject]
```

**What the port does instead:** filters and ranks in Ruby in one pass per
search term and splices the result into a plain `Gio::ListStore`
(`lib/search_view.rb#rank`). The resulting order is identical, because
upstream's filter already visits every page and its sorter already orders every
match.

**Reported upstream:** no — this is a ruby-gnome defect, not a Biblioteca one.
Not yet filed against ruby-gnome.

---

## 2. `GLib::Uri` is not in the Ruby bindings

**Where it bit:** `lib/web_view.rb`. Upstream reads a URI's scheme with
`GLib.Uri.peek_scheme(uri)` (`src/WebView.js`).

**What happens:** `glib2` 4.3.9 binds no `GLib::Uri` class at all —
`GLib.const_defined?(:Uri)` is false — because `GLib-2.0.gir`'s `Uri` record is
not in the hand-written C half of the gem and `glib2` is not GIR-loaded.

**Reproduction:**

```ruby
require 'glib2'
GLib.const_defined?(:Uri)   # => false
```

**What the port does instead:** `WebView.scheme_of` matches RFC 3986's scheme
production with a regexp and returns `nil` for a string with no scheme, which
is what `peek_scheme` returns too (`lib/web_view.rb`).

**Reported upstream:** no — ruby-gnome defect. Not yet filed.

---

## 3. A widget class's CSS name cannot be set from Ruby

**Where it bit:** `lib/theme_selector.rb`. troll registers `ThemeSelector` with
`CssName: "themeselector"` and writes its whole stylesheet against that element
name (`troll/src/widgets/ThemeSelector.{js,css}`).

**What happens:** `gtk_widget_class_set_css_name` operates on a
`GtkWidgetClass`, which the Ruby bindings never expose: `type_register` has no
option for it and there is no `Gtk::Widget.css_name=`. The only hook on an
instance is `Gtk::Widget#name=`, which sets the `#id` selector, not the element
name.

**Reproduction:**

```ruby
require 'gtk4'
Gtk::Widget.respond_to?(:set_css_name)   # => false
Gtk::Widget.respond_to?(:css_name=)      # => false
```

**What the port does instead:** the root carries the style class
`.themeselector` and every rule in `ThemeSelector::CSS` selects
`.themeselector` where troll's selects `themeselector`. Same rules, same
cascade order, one less element-name selector.

**Reported upstream:** no — ruby-gnome defect. Not yet filed.

---

## 4. `gtk_accessible_update_property` has no usable Ruby form

**Where it bit:** `lib/theme_selector.rb`. `ThemeSelector.blp` gives each check
button an `accessibility { label: … }` block alongside its tooltip.

**What happens:** `gtk_accessible_update_property` is variadic and therefore
not introspectable; the introspectable
`gtk_accessible_update_property_value(accessible, properties, values)` takes a
`GValue` array, and the loader exposes no way to build one from Ruby.

**Reproduction:**

```ruby
require 'gtk4'
Gtk::CheckButton.new.respond_to?(:update_property)   # => false
```

**What the port does instead:** builds each check button from a GtkBuilder
document that carries the `<accessibility>` block, then sets the rest of its
properties on the instance. GtkBuilder parses accessible properties itself and
never goes near the introspected setter, so the label does get set — this is
the same escape hatch `lib/find_overlay.rb` uses for a construct-only
`css-name` (#3).

```ruby
require 'gtk4'
ui = <<~XML
  <interface>
    <object class="GtkCheckButton" id="b">
      <accessibility><property name="label">Dark style</property></accessibility>
    </object>
  </interface>
XML
Gtk::Builder.new(string: ui)['b']   # => #<Gtk::CheckButton>, no warning
```

What is still missing is a way to *read* the property back, so the label is
verified by the builder accepting the document and by the button it hands back
working (`test/drive_app.rb`, "the theme selector has three choices" and the
two swatch steps), not by reading the accessible node.

---

## 5. Upstream bug: a background tab's load drives the foreground progress bar

**Upstream:** `src/window.js:200-233`. Every per-tab handler writes
`this._webview` — whichever view is *selected* — rather than the view that
emitted:

```js
webview.connect("notify::estimated-load-progress", () => {
  this._load_bar.fraction = this._webview.estimated_load_progress;
  ...
});
```

Each tab's handler stays connected while the tab lives, so a background tab
loading a remote page writes the foreground tab's progress bar, and its
`notify::title` writes the foreground tab's header and window title for as long
as the background load runs.

**How to see it:** open a documentation page, open a second tab on a slow
remote URL (the Bookmarks submenu's DevDocs entry will do), switch back to the
first tab before the second finishes. The progress bar under the first tab's
header fills for the second tab's load.

**What the port does instead:** every one of those handlers is guarded on
`view.equal?(webview)` — `lib/window.rb#on_title_changed`, `#on_uri_changed`,
`#on_load_progress`, `#on_zoom_changed` — so only the selected view writes the
chrome. This is a deliberate divergence from upstream and the only one in the
port that changes behaviour the user can see.

The tab's *own* title is still written whichever view emitted, because that is
that page's title and not the window's: only the two window-level writes in
`#on_title_changed` (the content page's title and the window's) are guarded.

**This claim was false until `test/drive_biblioteca.rb` was written.**
`#on_title_changed` was the one handler of the four with no guard, so a
background tab finishing its load retitled the foreground tab's header and the
window — exactly the upstream bug this entry says the port does not have. The
drive script caught it as an intermittent failure of "the content page title
followed the switch" and now pins it with a deliberate check ("a background
tab's title does not reach the foreground chrome"), which drives a background
load and asserts the foreground chrome does not move.

**Reported upstream:** not yet. Owed to
<https://github.com/workbenchdev/Biblioteca/issues>.

---

## 6. Upstream bug: a Devel build cannot find its catalogue

**Upstream:** `src/main.js:4` calls `pkg.initGettext()`, which binds the
domain `pkg.name`. For a development build `pkg.name` is
`app.drey.Biblioteca.Devel` (`meson.build:9`), and `data/meson.build` installs
the catalogue under the same substituted `app_id`, so each profile needs its
own catalogue. The project ships none, so the bug is latent rather than
visible.

**What the port does instead:** `Package::DOMAIN` is the release id for both
profiles (`lib/package.rb`), so one `po/` serves the Devel build as well.

**Reported upstream:** not yet. Low priority — upstream has no catalogue to
orphan.

---

## 7. `GtkShortcutsWindow` is deprecated and still the only complete option

**Where it bit:** `data/ui/shortcuts.ui`, `lib/shortcuts_window.rb`.

`AdwShortcutsDialog` is GTK 4.18's replacement for `GtkShortcutsWindow`, and it
is missing two things upstream's dialog uses:

* a `section -> group -> shortcut` hierarchy. `AdwShortcutsDialog` holds
  `AdwShortcutsSection`s holding `AdwShortcutsItem`s — one level, not two.
* `GtkShortcutsShortcut:shortcut-type`, and with it
  `gesture_two_finger_swipe_left` / `_right`, which draw GTK's swipe
  illustration. `AdwShortcutsItem` has `title`, `subtitle`, `accelerator`,
  `action-name` and `direction` and nothing else (verified against
  `Adw-1.gir` 1.9.3).

Worth recording on the other side: `AdwShortcutLabel`'s accelerator syntax —
which `AdwShortcutsItem:accelerator` uses — *does* accept alternatives
separated by spaces and ranges separated by `...`, so
`"<Control>Page_Down <Control>Tab"` and `"<Alt>1...0"` would have rendered
correctly there. It was the hierarchy and the gestures that decided it.

**What the port does:** keeps a `GtkShortcutsWindow`, built from
`data/ui/shortcuts.ui`, a line-for-line translation of `src/Shortcuts.blp`. The
widget is deprecated in GTK 4.18 and present and functional in 4.22. When GTK
removes it, the two gesture rows are what will have to be rebuilt by hand.

---

## 8. Not a bug: `<Ctrl>Home` in `src/Shortcuts.blp:36`

It looks like a typo for `<Control>Home` and it is not one:
`gtk_accelerator_parse` accepts `<Ctrl>` and `<Ctl>` as aliases for
`<Control>`. `data/ui/shortcuts.ui` carries upstream's bytes unchanged.

---

## 9. Not a port bug: the two gesture rows warn on every shortcuts window

Opening the keyboard-shortcuts window prints, exactly twice:

```
Gtk-WARNING **: GtkLabel 0x… (label) reported min width -3, but sizes must be >= 0
```

**Where it comes from:** the two `GtkShortcutsShortcut`s whose
`shortcut-type` is `gesture_two_finger_swipe_right` / `_left`
(`data/ui/shortcuts.ui`, from `src/Shortcuts.blp`). A gesture row swaps its
accelerator label for the swipe illustration and leaves the label it is no
longer measuring in a state where it reports a negative minimum width; GTK
clamps the value and draws the row correctly. Two gesture rows, two warnings,
every time the window is constructed — not once per presentation.

**Reproduction:** build the window and never show it. The warnings are emitted
during construction, before `present`:

```ruby
ShortcutsWindow.new(app, window, default_uri: 'file:///x').install
# => two GtkLabel min width -3 warnings
```

**Why nothing here changes:** the markup is upstream's, the rows are two of
upstream's 26 shortcuts, and the only way to silence the warning is to drop the
gesture illustration — which is the behaviour being ported. The warning is
GTK's, is harmless, and upstream's own build prints it too. Recorded so the
next person reading `test/drive_app.rb`'s output does not go looking for it in
the port.

**Reported upstream:** no — a GTK defect in a widget GTK has already
deprecated (see #7). Not filed.

---

## 10. `ashpd` and `libspelling` wired in, used by neither upstream nor the port

Both gems are declared in `biblioteca-rb.gemspec` and `nix/Gemfile`, and both
load: `require "ashpd"; Ashpd.constants` returns 7 constants
(`Account`, `Camera`, `OpenUri`, `Screenshot`, `Settings`, `Trash`, `VERSION`)
and `require "libspelling"; Spelling.constants` returns 8
(`Checker`, `Dictionary`, `Error`, `LOG_DOMAIN`, `Language`, `Loader`,
`Provider`, `TextBufferAdapter`). `flake.nix` carries `libspelling` in
`gtkStack` for its typelib, and rewrites `ashpd`'s gemset entry to the
platform gem for the build system the way `gnome-maps-rb`'s flake does, since
the Rust source gem wants `cargo` at build time.

**Why nothing calls into either.** `git grep -i spelling` over
`origin/main`'s whole tree, including `src/*.js` and every `*.blp`, matches
nothing: `libspelling` appears only in
`build-aux/modules/libspelling.json`, a Flatpak module that unpacks a
`gi-docgen` documentation `.deb` so the sandboxed build has offline API docs
to browse — it is build tooling, not a GI namespace `src/main.js` imports, and
there is no `GtkSourceView`/`GtkTextView` anywhere in the app for a spell
checker to attach to; `Sidebar.blp`'s search entry is a plain
`Gtk::SearchEntry` upstream never spell-checks.

`Xdp` (the GI namespace `ashpd` is the Rust-native equivalent of) appears only
in `src/bin.js:6,19`, where `Xdp.Portal.running_under_flatpak()` refuses to
start outside Flatpak. Stated plainly: that literal check is not implemented
in this port, and cannot be — the port is a gem, installed by RubyGems or run
from a checkout, so there is no Flatpak sandbox for `running_under_flatpak()`
to detect. Until this round, nothing stood in for it at all, which is a
missing feature, not a settled decision — the app opened on a permanently
empty sidebar with no explanation on a machine with no GNOME API docs
installed, exactly the failure mode upstream's guard exists to head off.

This round adds `exe/biblioteca`'s own startup refusal, built on the one
condition this port can check in its place: `DocIndex.default_root` finding no
documentation root at all. It prints the same kind of message upstream's
`console.error` does and calls `exit(1)`, so the port now refuses to start
rather than opening uselessly — not the Flatpak check ported, because there is
nothing to port it to, but the gap it left (an app that starts and shows
nothing) closed on these terms. Inventing a new "open externally through the
portal" feature nowhere in upstream's `WebView.js`/`Sidebar.js` navigation
handling, just to have somewhere to call `Ashpd::OpenUri.open`, would still be
adding behaviour the spec does not have, and this round does not do that.

Both gems are real dependencies, proven to load, kept in the lockfile and the
flake's typelib path, ready for the day a future upstream commit adds a text
editor or a portal-mediated open. Until then there is no upstream call site to
port, and the honest state of this round is: wired, loadable, unused — not a
hand-rolled substitute removed, because none existed.

**Reported upstream:** n/a — not a port divergence, a gap in what upstream's
own source calls.

---

## 11. `GtkSingleSelection.autoselect` overrides the -1 both the port and upstream assign

**Where it bit:** `lib/sidebar.rb#start_index`/`#selection_index`.
`doc_index['start_index']` is `-1` when the GTK docs are not indexed
(`lib/doc_index.rb#start_index`). An earlier round of this port clamped that
to `0` before assigning it to `browse_view.selection_model.selected`, read as
a divergence from upstream's `src/sidebar/Sidebar.js:59`, which assigns the
raw `-1` and (so the reasoning went) therefore leaves nothing selected.

**What actually happens, verified against this checkout's real GTK4 typelib
(the same C `GtkSingleSelection` GJS binds too, not a Ruby-bindings quirk):**
`GtkSingleSelection:autoselect` defaults to `true`, and neither
`src/sidebar/BrowseView.js#createBrowseSelectionModel` nor
`lib/browse_view.rb#selection_model` sets it to `false` — both set only
`can-unselect`. With `autoselect` true, assigning any out-of-range or
`GTK_INVALID_LIST_POSITION` value to `selected` on a non-empty model is
immediately overridden back to row 0:

```ruby
require 'gtk4'
store = Gio::ListStore.new(Gtk::StringObject)
store.append(Gtk::StringObject.new('a'))
sel = Gtk::SingleSelection.new(store)
sel.can_unselect = true
sel.selected = 0xFFFFFFFF   # GTK_INVALID_LIST_POSITION
sel.selected                # => 0, not 0xFFFFFFFF
```

So upstream's `-1` and this port's sentinel both land on row 0 whenever the
tree holds anything at all — they were never actually divergent in what the
sidebar shows. The only place a negative `start_index` was genuinely mishandled
was `Sidebar#start_uri`, which indexed `docs[start_index]` directly: Ruby's
negative indexing turned `-1` into "the *last* page in the index", not "no
page", which upstream's own equivalent concept does not have (`start_uri` is
this port's addition, replacing the Flatpak-only hardcoded default new-tab uri
— see `COMPONENT_PARITY.md` row 5). That is fixed; the selection assignment is
kept as a sentinel for correctness in principle, with this finding attached so
a future reader does not reach for `autoselect = false` to "fix" something
that was never actually broken on screen, which would itself be a new
divergence from upstream neither file asks for.

**Reported upstream:** no — intended GTK behaviour, not a defect.

---

## 12. Upstream bugs, newly observable: both AppStream validators reject `data/app.metainfo.xml` as upstream wrote it

**Where it bit:** `rake data:validate`. `desktop-file-utils`, `appstream` and
`appstream-glib` were all missing from the Nix devshell until this round
(TEST_PARITY.md), so this check had never actually run anything. With all
three present:

```
$ appstreamcli validate --no-net data/app.metainfo.xml
I: org.rubygtkproject.Biblioteca:38: nonstandard-gnome-extension kudos
W: org.rubygtkproject.Biblioteca:57: invalid-iso8601-date 2026-09-xx

$ appstream-util validate data/app.metainfo.xml
• style-invalid     : <image> has vertical padding [...screenshot.png]
• style-invalid     : <image> has horizontal padding [...screenshot.png]
• attribute-missing : <release> has no timestamp
• style-invalid     : <ul> cannot start a description [(null)]
• style-invalid     : Not enough <p> tags for a good description [0/1]
```

**What it is:** every one of these — the placeholder release date
`date="2026-09-xx"` at line 57, the `<ul>`-first description, the thin
`<p>` count, the unspecified `<release>` timestamp, the screenshot's padding —
is upstream's own content. `diff` against `git show
origin/main:data/app.metainfo.xml` (normalised for `@app_id@`) is empty: this
port's `data/app.metainfo.xml` is upstream's file with the app id substituted
and nothing else, so every one of these is an upstream defect surfacing for
the first time because the port's tooling can finally see it, not something
this round introduced.

**What the port does instead:** nothing — the text is kept exactly as
upstream wrote it, rather than "fixed" by diverging from the spec. `rake
data:validate` is therefore not wired into `rake default`; it is run on its
own, where its non-zero exit is the accurate, honest result rather than
something that would make every other CI run fail for upstream content this
port does not own.

**Reported upstream:** no — not yet filed against
<https://github.com/workbenchdev/Biblioteca/issues>.
