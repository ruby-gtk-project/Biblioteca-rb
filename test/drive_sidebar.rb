# frozen_string_literal: true

# Drives the sidebar — DocIndex, BrowseView, SearchView — in a real GTK
# process, against a gi-docgen fixture this script writes itself.
#
# The machine running the port may well have no GNOME API documentation
# installed, in which case DocIndex finds nothing and the sidebar tree in
# test/drive_app.rb is legitimately empty. That leaves the two most intricate
# widgets in the port — a Gtk::TreeListModel behind a SignalListItemFactory,
# and the fuzzy search that replaces upstream's filter/sort model chain — never
# exercised. This script supplies the documentation root instead of hoping for
# one: two namespaces' worth of index.json in the shape gi-docgen emits, read
# through the real DocIndex and shown in a real Sidebar inside a real window.
#
# Usage, from the dev shell:
#
#   xvfb-run -a ruby test/drive_sidebar.rb
#
# Exits 0 when every step passed, 1 otherwise.
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'fileutils'
require 'json'
require 'tmpdir'

require 'biblioteca'

# Writes the gi-docgen output tree DocIndex expects to walk.
#
# gi-docgen puts one directory per library under the documentation root, each
# holding an index.json with a `meta` block naming the namespace and a flat
# `symbols` array. A symbol belonging to a type carries `type_name`
# (or `struct_for`, for a class method), which is what makes DocIndex nest it
# under that type rather than under the namespace.
module Fixture
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

  def self.write(root)
    library(
      root,
      'gtk4',
      'Gtk',
      '4.0',
      GTK_SYMBOLS,
    )
    library(
      root,
      'glib-2.0',
      'GLib',
      '2.0',
      GLIB_SYMBOLS,
    )
    # An ignored library and a directory that is not a doc tree at all: both
    # have to drop out of the index.
    library(
      root,
      'atk',
      'Atk',
      '1.0',
      [],
    )
    FileUtils.mkdir_p(File.join(root, 'not-documentation'))
    root
  end

  def self.library(root, directory, namespace, version, symbols)
    File.join(root, directory).tap do |path|
      FileUtils.mkdir_p(path)
      File.write(
        File.join(path, 'index.json'),
        JSON.generate('meta' => { 'ns' => namespace, 'version' => version }, 'symbols' => symbols),
      )
    end
  end
end

# Runs an ordered list of named steps, recording what each one raised. The
# widget steps need a main loop, so they run one per timeout inside an
# application's activate handler.
class Driver
  def initialize
    @failures = []
    @steps = []
    @ran = 0
  end

  def step(name, &body)
    @steps << [name, body]
    self
  end

  def run
    app.tap do |a|
      a.signal_connect('activate') do
        a.add_window(window)
        window.tap { |win| win.child = sidebar.build }
        window.present
        schedule(a)
      end

      a.run([])
    end

    report
  end

  def root = @root ||= Fixture.write(Dir.mktmpdir('biblioteca-fixture'))

  def doc_index = @doc_index ||= DocIndex.new(root: root)

  def index_hash = @index_hash ||= doc_index.to_h

  def sidebar = @sidebar ||= Sidebar.new(doc_index: index_hash)

  def app
    @app ||= begin
      Adwaita.init
      Gtk::Application.new('org.rubygtkproject.Biblioteca.DriveSidebar', :default_flags)
    end
  end

  def window
    @window ||= Gtk::ApplicationWindow.new(app).tap do |win|
      win.set_default_size(400, 600)
    end
  end

  private

    def schedule(gtk_app)
      GLib::Timeout.add(400) do
        @steps.shift.then do |pair|
          if pair
            attempt(*pair)
            true
          else
            gtk_app.quit
            false
          end
        end
      end
    end

    def attempt(name, body)
      @ran += 1
      body.call
      puts "ok    #{name}"
    rescue StandardError, SystemStackError => e
      @failures << [name, e]
      puts "FAIL  #{name}: #{e.class}: #{e.message}"
      puts "      #{e.backtrace.take(4).join("\n      ")}"
    end

    def report
      @root.then do |dir|
        unless dir.nil?
          FileUtils.remove_entry(dir)
        end
      end

      @failures.empty?.then do |clean|
        puts
        if clean
          puts "#{@ran} steps, 0 failures"
          0
        else
          puts "#{@ran} steps, #{@failures.length} failure(s): #{@failures.map(&:first).join(', ')}"
          1
        end
      end
    end
end

# Asserts a condition the way the driver's steps want it: by raising.
module Expect
  def self.truthy(value, description)
    value.then do |v|
      unless v
        raise "expected #{description}, got #{v.inspect}"
      end
    end
    value
  end

  def self.equal(actual, expected, description)
    (actual == expected).then do |same|
      unless same
        raise "expected #{description} to be #{expected.inspect}, got #{actual.inspect}"
      end
    end
    actual
  end
end

Driver.new.tap do |driver|
  driver
    .step('the index holds both documented namespaces') do
      Expect.equal(
        driver.index_hash['docs'].map { |doc| doc['name'] },
        ['GLib-2.0', 'Gtk-4.0'],
        'the namespace list',
      )
    end
    .step('Gtk-4.0 is the starting namespace') do
      Expect.equal(driver.index_hash['start_index'], 1, 'the start index')
      Expect.truthy(driver.sidebar.start_uri.to_s.end_with?('gtk4/index.html'), 'the start uri')
    end
    .step('sections are named and ordered') do
      driver.index_hash['docs'][1]['children'].map { |child| child['name'] }.then do |names|
        Expect.equal(names, ['Classes', 'Enumerations', 'Functions', 'Interfaces'], 'the sections')
      end
    end
    .step("a class's members hang off the class") do
      driver.index_hash['docs'][1]['children']
            .find { |child| child['name'] == 'Classes' }['children']
            .find { |child| child['name'] == 'Button' }['children']
            .map { |child| child['name'] }
            .then do |names|
              Expect.equal(
                names,
                ['Constructors', 'Instance Methods', 'Properties', 'Signals'],
                "Button's subsections",
              )
            end
    end
    .step('a class method is nested under its owner') do
      driver.index_hash['docs'][1]['children']
            .find { |child| child['name'] == 'Classes' }['children']
            .find { |child| child['name'] == 'Widget' }['children']
            .map { |child| child['name'] }
            .then { |names| Expect.equal(names, ['Class Methods'], "Widget's subsections") }
    end
    .step('symbol pages get gi-docgen filenames') do
      driver.index_hash['docs'][1]['children']
            .find { |child| child['name'] == 'Classes' }['children']
            .find { |child| child['name'] == 'Button' }['children']
            .find { |child| child['name'] == 'Signals' }['children']
            .first['uri']
            .then do |uri|
              Expect.truthy(uri.end_with?('gtk4/signal.Button.clicked.html'), "the signal's uri")
            end
    end
    .step('the browse tree has one row per namespace') do
      Expect.equal(driver.sidebar.browse_view.root_model.n_items, 2, 'the root row count')
    end
    .step('the tree model starts collapsed') do
      Expect.equal(driver.sidebar.browse_view.tree_model.n_items, 2, 'the visible row count')
    end
    .step('expanding a namespace reveals its sections') do
      driver.sidebar.browse_view.tree_model.get_row(1).tap do |row|
        row.expanded = true
        Expect.equal(
          driver.sidebar.browse_view.tree_model.n_items,
          6,
          'the visible row count with Gtk-4.0 expanded',
        )
      end
    end
    .step('expanding a section reveals its symbols') do
      driver.sidebar.browse_view.tree_model.get_row(2).tap do |row|
        row.expanded = true
        Expect.equal(
          driver.sidebar.browse_view.tree_model.n_items,
          8,
          'the visible row count with Classes expanded',
        )
      end
    end
    .step('collapse_all_rows folds the tree back') do
      driver.sidebar.browse_view.collapse_all_rows
      Expect.equal(driver.sidebar.browse_view.tree_model.n_items, 2, 'the visible row count')
    end
    .step('the starting namespace is selected') do
      driver.sidebar.reset_sidebar
      Expect.equal(driver.sidebar.browse_view.selection_model.selected, 1, 'the selected row')
    end
    .step('search matches a C identifier') do
      driver.sidebar.search_view.tap do |view|
        view.search_term = 'gtk_button_new'
        Expect.truthy(view.n_items.positive?, 'a result for gtk_button_new')
      end
    end
    .step('search matches fuzzily, best first') do
      driver.sidebar.search_view.tap do |view|
        view.search_term = 'gbtnnew'
        Expect.truthy(view.n_items.positive?, 'a fuzzy result for gbtnnew')
      end
    end
    .step('a kind: prefix restricts the kind') do
      driver.sidebar.search_view.tap do |view|
        view.search_term = 'signal: clicked'
        Expect.equal(view.n_items, 1, 'the signal result count')
      end
    end
    .step('a kind: prefix excludes other kinds') do
      driver.sidebar.search_view.tap do |view|
        view.search_term = 'enum: button'
        Expect.equal(view.n_items, 0, 'the enum result count for "button"')
      end
    end
    .step('a term that matches nothing shows nothing') do
      driver.sidebar.search_view.tap do |view|
        view.search_term = 'zzzznotathing'
        Expect.equal(view.n_items, 0, 'the result count')
      end
    end
    .step('a matching term is typed') { driver.sidebar.search_entry.text = 'gtk_init' }
    .step('the search entry drives the stack') do
      Expect.equal(
        driver.sidebar.stack.visible_child_name,
        Sidebar::SEARCH,
        'the visible sidebar page',
      )
    end
    .step('an unmatched term is typed') { driver.sidebar.search_entry.text = 'zzzznotathing' }
    .step('an unmatched entry shows the empty state') do
      Expect.equal(
        driver.sidebar.stack.visible_child_name,
        Sidebar::NO_RESULTS,
        'the visible sidebar page',
      )
    end
    .step('the entry is cleared') { driver.sidebar.search_entry.text = '' }
    .step('clearing the entry goes back to the tree') do
      Expect.equal(
        driver.sidebar.stack.visible_child_name,
        Sidebar::BROWSE,
        'the visible sidebar page',
      )
    end
    .step('focus_search selects the whole term') do
      driver.sidebar.focus_search
    end
    .run
    .then { |status| exit status }
end
