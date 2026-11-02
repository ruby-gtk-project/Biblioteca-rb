# frozen_string_literal: true

require 'gtk4'

require_relative 'fzy'

# DocumentationPage is one node of the sidebar's documentation tree: a
# namespace, a section, a subsection or a single symbol's page.
#
# Ported from upstream's src/sidebar/DocumentationPage.js, which registers a
# GObject carrying name / tag / search_name / score / uri / children. The
# fields are the same. They are plain Ruby accessors rather than GObject
# properties because nothing binds to them: upstream's rows come from a
# BuilderListItemFactory whose `bind` expressions need real properties, while
# this port builds its rows with a Gtk::SignalListItemFactory and reads the
# page directly.
#
# It still has to be a GLib::Object — Gio::ListStore only holds GObjects, and
# the whole tree is nested list stores.
class DocumentationPage < GLib::Object
  type_register

  # `name` is what the browse tree shows, `search_name` is the fully qualified
  # name the search view shows and fzy matches against, and `tag` is the kind
  # of symbol ("class", "method", …) shown as a pill beside it. Section and
  # subsection nodes have a name and children but no search_name, which is how
  # the flattened search model skips them.
  attr_accessor :name, :tag, :search_name, :uri, :score, :children

  def initialize(name: nil, tag: nil, search_name: nil, uri: nil, children: nil)
    super()
    @name = name
    @tag = tag
    @search_name = search_name
    @uri = uri
    @children = children
    @score = Fzy::SCORE_MIN
  end

  # Upstream's `Gio.ListStore.new(DocumentationPage)`, which it calls for the
  # root model and once per node that has children.
  def self.list_store = Gio::ListStore.new(DocumentationPage)

  # A row that carries a searchable symbol name, as opposed to one of the
  # section headings the tree groups symbols under.
  def searchable? = !search_name.to_s.empty?

  def children? = !children.nil?
end
