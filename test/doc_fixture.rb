# frozen_string_literal: true

require 'fileutils'
require 'json'

# DocFixture writes a gi-docgen output tree — the thing DocIndex walks — plus
# the HTML pages its index.json points at.
#
# Why it exists: the machine running this port very likely has no GNOME API
# documentation installed, and with none installed DocIndex correctly returns
# an empty index. An empty index leaves the two most intricate widgets in the
# port — the Gtk::TreeListModel behind a SignalListItemFactory, and the fuzzy
# search that replaces upstream's filter/sort model chain — never exercised,
# and leaves the web view with nothing to load, so find-in-page, the title
# handlers, the progress bar and the back/forward buttons all sit idle too.
#
# So the documentation is supplied rather than hoped for. The directory layout,
# the `meta` block, the flat `symbols` array and the per-symbol `type_name` /
# `struct_for` ownership keys are all the shapes gi-docgen really emits, and
# the HTML pages are real files on disk at the paths DocIndex#link_for
# computes, so every uri in the built index resolves.
module DocFixture
  # FindOverlay's counter is only interesting when a page has more than one
  # match, so every page below carries NEEDLE exactly MATCHES times — and
  # nowhere else, not in the title and not in the heading, so the count is the
  # same on every page in the fixture whatever its name.
  NEEDLE = 'xyzzyneedle'
  MATCHES = 4

  # The `devhelp-hidden` div is what WebView's injected stylesheet hides: it
  # stands in for the sidebar devhelp generates into every page, which this app
  # replaces with its own. It is a child element and not the body, because a
  # hidden body would make the whole page unfindable — which is how this
  # fixture first learned that the stylesheet is really applied.
  PAGE = <<~HTML
    <!DOCTYPE html>
    <html><head><title>%<title>s</title></head>
    <body>
      <div class="devhelp-hidden">Generated sidebar, hidden by the app</div>
      <h1>%<title>s</h1>
      <p>#{([NEEDLE] * MATCHES).join(" ")}</p>
      <p>A page of generated documentation.</p>
    </body></html>
  HTML

  GTK_SYMBOLS = [
    { 'type' => 'class', 'name' => 'Widget', 'ctype' => 'GtkWidget' },
    { 'type' => 'class', 'name' => 'Button', 'ctype' => 'GtkButton' },
    { 'type' => 'interface', 'name' => 'Editable', 'ctype' => 'GtkEditable' },
    { 'type' => 'enum', 'name' => 'Align', 'ctype' => 'GtkAlign' },
    { 'type' => 'function', 'name' => 'init', 'ident' => 'gtk_init' },
    { 'type' => 'ctor', 'name' => 'new', 'type_name' => 'Button', 'ident' => 'gtk_button_new' },
    {
      'type'      => 'method',
      'name'      => 'set_label',
      'type_name' => 'Button',
      'ident'     => 'gtk_button_set_label',
    },
    { 'type' => 'property', 'name' => 'label', 'type_name' => 'Button' },
    { 'type' => 'signal', 'name' => 'clicked', 'type_name' => 'Button' },
    {
      'type'       => 'class_method',
      'name'       => 'install_action',
      'struct_for' => 'Widget',
      'ident'      => 'gtk_widget_class_install_action',
    },
  ].freeze

  GLIB_SYMBOLS = [
    { 'type' => 'record', 'name' => 'Bytes', 'ctype' => 'GBytes' },
    { 'type' => 'function', 'name' => 'getenv', 'ident' => 'g_getenv' },
  ].freeze

  # The pages each library's index.json points at, keyed by the filename
  # DocIndex#link_for derives for the matching symbol.
  GTK_PAGES = %w[
    index.html
    class.Widget.html
    class.Button.html
    iface.Editable.html
    enum.Align.html
    func.init.html
    ctor.Button.new.html
    method.Button.set_label.html
    property.Button.label.html
    signal.Button.clicked.html
    class_method.Widget.install_action.html
  ].freeze

  GLIB_PAGES = %w[index.html struct.Bytes.html func.getenv.html].freeze

  # The two namespaces the fixture documents, in the order DocIndex sorts them
  # into (case-insensitive by name, so GLib-2.0 comes before Gtk-4.0).
  NAMESPACES = ['GLib-2.0', 'Gtk-4.0'].freeze

  # Every searchable page in the fixture: one per namespace node plus one per
  # symbol. Section and subsection nodes carry no search_name, which is how
  # the flattened search model skips them.
  SEARCHABLE_PAGES = 2 + GTK_SYMBOLS.length + GLIB_SYMBOLS.length

  # Every distinct uri the built index contains, so a caller can check that
  # the sidebar recorded a tree path for each of them.
  def self.node_uris(docs)
    docs.flat_map { |node| [node['uri']] + node_uris(node.fetch('children', [])) }.uniq
  end

  def self.write(root)
    library(
      root,
      'gtk4',
      'Gtk',
      '4.0',
      GTK_SYMBOLS,
      GTK_PAGES,
    )
    library(
      root,
      'glib-2.0',
      'GLib',
      '2.0',
      GLIB_SYMBOLS,
      GLIB_PAGES,
    )
    # An ignored library and a directory that is not a doc tree at all: both
    # have to drop out of the index.
    library(
      root,
      'atk',
      'Atk',
      '1.0',
      [],
      ['index.html'],
    )
    FileUtils.mkdir_p(File.join(root, 'not-documentation'))
    root
  end

  def self.library(root, directory, namespace, version, symbols, pages)
    File.join(root, directory).tap do |path|
      FileUtils.mkdir_p(path)
      File.write(
        File.join(path, 'index.json'),
        JSON.generate('meta' => { 'ns' => namespace, 'version' => version }, 'symbols' => symbols),
      )
      pages.each do |page|
        File.write(File.join(path, page), format(PAGE, title: "#{namespace} #{page}"))
      end
    end
  end
end
